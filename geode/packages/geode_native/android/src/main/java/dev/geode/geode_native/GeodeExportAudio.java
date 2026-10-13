package dev.geode.geode_native;

import android.content.Context;
import android.media.AudioFormat;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.net.Uri;
import java.io.File;
import java.io.FileOutputStream;
import java.io.RandomAccessFile;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CancellationException;
import java.util.function.BooleanSupplier;
import static dev.geode.geode_native.GeodeExportRenderer.*;

/** Bounded-memory offline stereo decode, resampling and additive timeline mixing. */
final class GeodeExportAudio implements AutoCloseable {
    static final int RATE = 48000;
    private final List<Source> sources = new ArrayList<>();
    private final BooleanSupplier cancelled;
    private float gain = 1;
    private static final class Source {
        final Map<String, Object> clip;
        final File file;
        final RandomAccessFile pcm;
        final int rate;
        Source(Map<String, Object> clip, File file, int rate) throws Exception {
            this.clip = clip; this.file = file; this.rate = rate; pcm = new RandomAccessFile(file, "r");
        }
    }

    GeodeExportAudio(Context context, Map<String, Object> project, BooleanSupplier cancelled) throws Exception {
        this.cancelled = cancelled;
        try {
            for (Map<String, Object> clip : maps(project.get("clips"))) {
                if (!"audio".equals(clip.get("lane")) || Boolean.FALSE.equals(clip.get("enabled")) ||
                    Boolean.TRUE.equals(map(map(project.get("lanes")).get("audio")).get("muted"))) continue;
                check();
                sources.add(decode(context, clip));
            }
        } catch (Throwable error) { close(); throw error; }
    }
    boolean isEmpty() { return sources.isEmpty(); }
    void check() { if (cancelled.getAsBoolean()) throw new CancellationException("Export cancelled"); }

    void normalize(long startMs, long endMs) throws Exception {
        float peak = 0;
        long total = (endMs - startMs) * RATE / 1000;
        for (long frame = 0; frame < total; frame += 4096) {
            check();
            float[] block = read(startMs * RATE / 1000 + frame, (int)Math.min(4096, total - frame));
            for (float value : block) peak = Math.max(peak, Math.abs(value));
        }
        if (peak > .00001f) gain = Math.min(8, .95f / peak);
    }

    float[] read(long frame, int frames) throws Exception {
        check();
        float[] mixed = new float[frames * 2];
        for (Source source : sources) {
            long clipStart = number(source.clip, "startMs", 0) * RATE / 1000;
            long clipEnd = clipStart + number(source.clip, "durationMs", 4000) * RATE / 1000;
            long begin = Math.max(frame, clipStart), end = Math.min(frame + frames, clipEnd);
            if (begin >= end) continue;
            double sourceStart = number(source.clip, "sourceInMs", 0) * source.rate / 1000.0;
            long first = (long)Math.floor(sourceStart + (begin - clipStart) * source.rate / (double)RATE);
            long last = (long)Math.ceil(sourceStart + (end - clipStart) * source.rate / (double)RATE) + 1;
            int bytes = (int)Math.min(Integer.MAX_VALUE, Math.max(0, Math.min((last - first) * 4, source.pcm.length() - first * 4)));
            if (bytes <= 0) continue;
            byte[] raw = new byte[bytes]; source.pcm.seek(first * 4); source.pcm.readFully(raw);
            ByteBuffer data = ByteBuffer.wrap(raw).order(ByteOrder.LITTLE_ENDIAN);
            Map<String, Object> transition = map(source.clip.get("transition"));
            long fade = number(transition, "durationMs", 0) * RATE / 1000;
            for (long at = begin; at < end; at++) {
                double p = sourceStart + (at - clipStart) * source.rate / (double)RATE - first;
                int index = (int)p;
                if (index * 4 + 3 >= bytes) break;
                double fraction = p - index;
                float envelope = fade <= 0 ? 1 : Math.min(1, (at - clipStart) / (float)fade);
                for (int channel = 0; channel < 2; channel++) {
                    float a = data.getShort(index * 4 + channel * 2) / 32768f;
                    float b = (index + 1) * 4 + channel * 2 + 1 < bytes
                        ? data.getShort((index + 1) * 4 + channel * 2) / 32768f : a;
                    mixed[(int)(at - frame) * 2 + channel] += (a + (b - a) * fraction) * envelope * gain;
                }
            }
        }
        return mixed;
    }

    private Source decode(Context context, Map<String, Object> clip) throws Exception {
        File output = File.createTempFile("geode-studio-audio-", ".pcm", context.getCacheDir());
        MediaExtractor extractor = new MediaExtractor();
        MediaCodec decoder = null;
        boolean success = false;
        try (FileOutputStream file = new FileOutputStream(output)) {
            extractor.setDataSource(context, Uri.parse(String.valueOf(clip.get("source"))), null);
            MediaFormat format = null;
            for (int i = 0; i < extractor.getTrackCount(); i++) {
                MediaFormat candidate = extractor.getTrackFormat(i);
                if (candidate.getString(MediaFormat.KEY_MIME).startsWith("audio/")) {
                    format = candidate; extractor.selectTrack(i); break;
                }
            }
            if (format == null) throw new IllegalArgumentException("No audio track in " + clip.get("label"));
            int rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE);
            int channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT);
            int encoding = AudioFormat.ENCODING_PCM_16BIT;
            format.setInteger(MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_16BIT);
            decoder = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME));
            decoder.configure(format, null, null, 0); decoder.start();
            boolean inputDone = false, done = false;
            long endUs = (number(clip, "sourceInMs", 0) + number(clip, "durationMs", 4000)) * 1000;
            long idleSince = System.nanoTime();
            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
            while (!done) {
                check();
                if (System.nanoTime() - idleSince > 30_000_000_000L) throw new IllegalStateException("Audio decoder stopped responding");
                if (!inputDone) {
                    int index = decoder.dequeueInputBuffer(1000);
                    if (index >= 0) {
                        ByteBuffer buffer = decoder.getInputBuffer(index);
                        int count = extractor.readSampleData(buffer, 0);
                        long time = extractor.getSampleTime();
                        if (count < 0 || time > endUs + 500000) {
                            decoder.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM); inputDone = true;
                        } else {
                            decoder.queueInputBuffer(index, 0, count, time, 0); extractor.advance();
                        }
                    }
                }
                int index = decoder.dequeueOutputBuffer(info, 10000);
                if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    MediaFormat actual = decoder.getOutputFormat();
                    rate = actual.getInteger(MediaFormat.KEY_SAMPLE_RATE);
                    channels = actual.getInteger(MediaFormat.KEY_CHANNEL_COUNT);
                    encoding = actual.containsKey(MediaFormat.KEY_PCM_ENCODING) ? actual.getInteger(MediaFormat.KEY_PCM_ENCODING)
                        : AudioFormat.ENCODING_PCM_16BIT;
                    if (encoding != AudioFormat.ENCODING_PCM_16BIT && encoding != AudioFormat.ENCODING_PCM_FLOAT)
                        throw new IllegalArgumentException("Unsupported decoded PCM format");
                    idleSince = System.nanoTime();
                } else if (index >= 0) {
                    idleSince = System.nanoTime();
                    ByteBuffer data = decoder.getOutputBuffer(index).duplicate().order(ByteOrder.LITTLE_ENDIAN);
                    data.position(info.offset); data.limit(info.offset + info.size);
                    int sampleBytes = encoding == AudioFormat.ENCODING_PCM_FLOAT ? 4 : 2;
                    int count = info.size / sampleBytes / channels;
                    byte[] stereo = new byte[count * 4];
                    ByteBuffer dest = ByteBuffer.wrap(stereo).order(ByteOrder.LITTLE_ENDIAN);
                    for (int i = 0; i < count; i++) {
                        short left = 0, right = 0;
                        for (int c = 0; c < channels; c++) {
                            short value = encoding == AudioFormat.ENCODING_PCM_FLOAT
                                ? (short)Math.round(Math.max(-1, Math.min(1, data.getFloat())) * 32767) : data.getShort();
                            if (c == 0) left = value;
                            if (c == 1) right = value;
                        }
                        dest.putShort(left); dest.putShort(channels == 1 ? left : right);
                    }
                    file.write(stereo);
                    done = (info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0 || info.presentationTimeUs >= endUs;
                    decoder.releaseOutputBuffer(index, false);
                }
            }
            file.flush();
            Source source = new Source(clip, output, rate); success = true; return source;
        } finally {
            if (decoder != null) { try { decoder.stop(); } catch (Exception ignored) {} decoder.release(); }
            extractor.release(); if (!success) output.delete();
        }
    }
    @Override public void close() {
        for (Source source : sources) { try { source.pcm.close(); } catch (Exception ignored) {} source.file.delete(); }
        sources.clear();
    }
}
