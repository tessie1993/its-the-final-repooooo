package dev.geode.geode_native;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.BitmapFactory;
import android.media.MediaCodec;
import android.media.MediaCodecInfo;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMetadataRetriever;
import android.media.MediaMuxer;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.view.Surface;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CancellationException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import static dev.geode.geode_native.GeodeExportRenderer.*;

/** Native Android export service using the retained C++ renderer, PCM analyzer and hardware codecs. */
final class GeodeVideoExporter implements MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {
    private static final int SAVE_REQUEST = 4867;
    private final Context context;
    private final MethodChannel channel;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private ActivityPluginBinding activity;
    private volatile boolean cancelled, closed;
    private boolean busy;
    private Map<String, Object> pendingProject;
    private MethodChannel.Result pendingResult;
    private GeodeExportRenderer preview;
    private GeodeExportAudio previewAudio;
    private String previewKey;

    GeodeVideoExporter(Context context, BinaryMessenger messenger) {
        this.context = context;
        channel = new MethodChannel(messenger, "dev.geode/export");
        channel.setMethodCallHandler(this);
    }
    void attach(ActivityPluginBinding binding) {
        activity = binding; binding.addActivityResultListener(this);
    }
    void detach() {
        if (activity != null) activity.removeActivityResultListener(this);
        activity = null;
    }
    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "render":
                    if (busy) throw new IllegalStateException("An export is already running");
                    if (activity == null) throw new IllegalStateException("Open the app to choose an export destination");
                    pendingProject = map(call.argument("project"));
                    validate(pendingProject);
                    cancelled = false; busy = true; pendingResult = result;
                    Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT).setType("video/mp4")
                        .addCategory(Intent.CATEGORY_OPENABLE).putExtra(Intent.EXTRA_TITLE,
                            String.valueOf(pendingProject.get("name")).replaceAll("[^a-zA-Z0-9 _-]", "") + ".mp4");
                    activity.getActivity().startActivityForResult(intent, SAVE_REQUEST);
                    return;
                case "cancel": cancelled = true; result.success(null); return;
                case "importMedia":
                    submit(result, () -> importMedia(String.valueOf(call.argument("uri")), String.valueOf(call.argument("name")))); return;
                case "preview":
                    if (busy) { result.success(null); return; }
                    Map<String, Object> project = map(call.argument("project"));
                    String key = String.valueOf(call.argument("key"));
                    long at = ((Number)call.argument("atMs")).longValue();
                    submit(result, () -> preview(project, key, at)); return;
                case "closePreview":
                    submit(result, () -> { closePreview(); return null; }); return;
                default: result.notImplemented();
            }
        } catch (Throwable error) { fail(result, error); }
    }
    private interface Work { Object run() throws Exception; }
    private void submit(MethodChannel.Result result, Work work) {
        if (closed) { result.error("export_closed", "Export service is closed", null); return; }
        worker.execute(() -> {
            try { Object value = work.run(); main.post(() -> result.success(value)); }
            catch (Throwable error) { main.post(() -> fail(result, error)); }
        });
    }
    @Override public boolean onActivityResult(int request, int code, Intent data) {
        if (request != SAVE_REQUEST || pendingResult == null) return false;
        MethodChannel.Result result = pendingResult;
        Map<String, Object> project = pendingProject;
        pendingResult = null; pendingProject = null;
        if (code != Activity.RESULT_OK || data == null || data.getData() == null) {
            busy = false; result.success(null); return true;
        }
        Uri destination = data.getData();
        worker.execute(() -> {
            try {
                closePreview();
                render(project, destination);
                main.post(() -> { busy = false; result.success(destination.toString()); });
            } catch (Throwable error) {
                try { android.provider.DocumentsContract.deleteDocument(context.getContentResolver(), destination); }
                catch (Exception ignored) {}
                main.post(() -> { busy = false; fail(result, error); });
            }
        });
        return true;
    }
    private void validate(Map<String, Object> project) {
        Map<String, Object> settings = map(project.get("export"));
        long width = number(settings, "width", 1920), height = number(settings, "height", 1080);
        long fps = number(settings, "fps", 30), start = number(settings, "rangeStartMs", 0), end = number(settings, "rangeEndMs", 1000);
        if (width < 64 || height < 64 || width > 8192 || height > 8192 || (width & 1) != 0 || (height & 1) != 0
            || fps < 1 || fps > 60 || end <= start || start < 0 || end > 86400000)
            throw new IllegalArgumentException("Invalid export size, frame rate or timeline range");
    }
    private byte[] preview(Map<String, Object> project, String key, long at) throws Exception {
        if (!key.equals(previewKey)) {
            closePreview();
            previewAudio = new GeodeExportAudio(context, project, () -> closed);
            try { preview = new GeodeExportRenderer(context, project, 640, 360, null); previewKey = key; }
            catch (Throwable error) { closePreview(); throw error; }
        }
        preview.render(at, previewAudio.read(at * GeodeExportAudio.RATE / 1000, 2048), -1);
        return preview.png();
    }
    private void closePreview() {
        if (preview != null) preview.close();
        if (previewAudio != null) previewAudio.close();
        preview = null; previewAudio = null; previewKey = null;
    }
    private Map<String, Object> importMedia(String value, String name) throws Exception {
        File directory = new File(context.getFilesDir(), "studio_media");
        if (!directory.isDirectory() && !directory.mkdirs()) throw new IllegalStateException("Cannot create studio media folder");
        String safeName = name.replaceAll("[^a-zA-Z0-9._-]", "_");
        File file = new File(directory, System.currentTimeMillis() + "-" + safeName);
        boolean success = false;
        try {
            try (InputStream in = context.getContentResolver().openInputStream(Uri.parse(value));
                 OutputStream out = new FileOutputStream(file)) {
                if (in == null) throw new IllegalArgumentException("Cannot open imported media");
                byte[] block = new byte[65536]; int count;
                while ((count = in.read(block)) >= 0) { if (closed) throw new CancellationException(); out.write(block, 0, count); }
            }
            Map<String, Object> result = new HashMap<>();
            result.put("uri", Uri.fromFile(file).toString());
            BitmapFactory.Options image = new BitmapFactory.Options(); image.inJustDecodeBounds = true;
            BitmapFactory.decodeFile(file.getAbsolutePath(), image);
            long duration = 0;
            String kind = "image";
            if (image.outWidth <= 0) {
                MediaMetadataRetriever media = new MediaMetadataRetriever();
                try {
                    media.setDataSource(file.getAbsolutePath());
                    String time = media.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
                    duration = time == null ? 0 : Long.parseLong(time);
                    kind = "yes".equals(media.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO)) ? "video" : "audio";
                } finally { media.release(); }
                if (duration <= 0) throw new IllegalArgumentException("This file has no readable media duration");
            }
            result.put("durationMs", duration); result.put("kind", kind);
            success = true; return result;
        } finally { if (!success) file.delete(); }
    }
    private void progress(String phase, double value) {
        main.post(() -> { if (!closed) channel.invokeMethod("progress", Map.of("phase", phase, "value", value)); });
    }
    private void check() { if (cancelled || closed) throw new CancellationException("Export cancelled"); }
    private void render(Map<String, Object> project, Uri destination) throws Exception {
        Map<String, Object> settings = map(project.get("export"));
        int width = (int)number(settings, "width", 1920), height = (int)number(settings, "height", 1080);
        int fps = (int)number(settings, "fps", 30), bitrate = (int)number(settings, "bitrateMbps", 12) * 1000000;
        long start = number(settings, "rangeStartMs", 0), end = number(settings, "rangeEndMs", 1000);
        File video = File.createTempFile("geode-export-video-", ".mp4", context.getCacheDir());
        File audio = File.createTempFile("geode-export-audio-", ".mp4", context.getCacheDir());
        File output = File.createTempFile("geode-export-final-", ".mp4", context.getCacheDir());
        try (GeodeExportAudio mix = new GeodeExportAudio(context, project, () -> cancelled || closed)) {
            progress("Preparing soundtrack", 0);
            if ("normalize".equals(settings.get("loudness"))) mix.normalize(start, end);
            String mime = "hevc".equals(settings.get("codec")) ? MediaFormat.MIMETYPE_VIDEO_HEVC : MediaFormat.MIMETYPE_VIDEO_AVC;
            MediaFormat format = MediaFormat.createVideoFormat(mime, width, height);
            format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface);
            format.setInteger(MediaFormat.KEY_BIT_RATE, bitrate);
            format.setInteger(MediaFormat.KEY_FRAME_RATE, fps);
            format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1);
            MediaCodec codec = MediaCodec.createEncoderByType(mime);
            Surface surface = null;
            boolean started = false;
            try (EncodedOutput encoded = new EncodedOutput(video)) {
                codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE);
                surface = codec.createInputSurface(); codec.start(); started = true;
                try (GeodeExportRenderer renderer = new GeodeExportRenderer(context, project, width, height, surface)) {
                    long frames = ((end - start) * fps + 999) / 1000;
                    for (long frame = 0; frame < frames; frame++) {
                        check();
                        long at = start + frame * 1000 / fps;
                        float[] pcm = mix.read(start * GeodeExportAudio.RATE / 1000 + frame * GeodeExportAudio.RATE / fps,
                            GeodeExportAudio.RATE / fps);
                        encoded.drain(codec, false);
                        renderer.render(at, pcm, frame * 1000000000L / fps);
                        if (frame % Math.max(1, fps / 4) == 0) progress("Rendering film", .05 + .75 * frame / frames);
                    }
                    codec.signalEndOfInputStream(); encoded.drain(codec, true);
                }
            } finally {
                if (started) try { codec.stop(); } catch (Exception ignored) {}
                codec.release(); if (surface != null) surface.release();
            }
            if (mix.isEmpty()) copy(video, output);
            else { encodeAudio(mix, start, end, audio); mux(video, audio, output); }
            check(); progress("Saving film", .97);
            try (InputStream in = new FileInputStream(output);
                 OutputStream out = context.getContentResolver().openOutputStream(destination, "w")) {
                if (out == null) throw new IllegalStateException("Cannot write selected destination");
                byte[] block = new byte[65536]; int count;
                while ((count = in.read(block)) >= 0) { check(); out.write(block, 0, count); }
            }
            progress("Film saved", 1);
        } finally { video.delete(); audio.delete(); output.delete(); }
    }
    private void encodeAudio(GeodeExportAudio mix, long start, long end, File file) throws Exception {
        MediaFormat format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, GeodeExportAudio.RATE, 2);
        format.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC);
        format.setInteger(MediaFormat.KEY_BIT_RATE, 192000);
        MediaCodec codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC);
        boolean started = false;
        try (EncodedOutput encoded = new EncodedOutput(file)) {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE); codec.start(); started = true;
            long total = (end - start) * GeodeExportAudio.RATE / 1000, frame = 0;
            long idleSince = System.nanoTime();
            while (frame < total) {
                check(); encoded.drain(codec, false);
                int index = codec.dequeueInputBuffer(10000);
                if (index < 0) {
                    if (System.nanoTime() - idleSince > 30_000_000_000L) throw new IllegalStateException("Audio encoder stopped responding");
                    continue;
                }
                idleSince = System.nanoTime();
                ByteBuffer buffer = codec.getInputBuffer(index).order(ByteOrder.LITTLE_ENDIAN);
                buffer.clear(); int frames = (int)Math.min(buffer.remaining() / 4, total - frame);
                float[] samples = mix.read(start * GeodeExportAudio.RATE / 1000 + frame, frames);
                for (float sample : samples) buffer.putShort((short)Math.round(Math.max(-1, Math.min(1, sample)) * 32767));
                codec.queueInputBuffer(index, 0, frames * 4, frame * 1000000 / GeodeExportAudio.RATE, 0);
                frame += frames;
                progress("Encoding soundtrack", .80 + .12 * frame / total);
            }
            boolean done = false; idleSince = System.nanoTime();
            while (!done) {
                check(); encoded.drain(codec, false);
                int index = codec.dequeueInputBuffer(10000);
                if (index >= 0) { codec.queueInputBuffer(index, 0, 0, total * 1000000 / GeodeExportAudio.RATE,
                    MediaCodec.BUFFER_FLAG_END_OF_STREAM); done = true; }
                if (System.nanoTime() - idleSince > 30_000_000_000L) throw new IllegalStateException("Audio encoder did not finish");
            }
            encoded.drain(codec, true);
        } finally { if (started) try { codec.stop(); } catch (Exception ignored) {} codec.release(); }
    }
    private final class EncodedOutput implements AutoCloseable {
        private final MediaMuxer muxer;
        private boolean started;
        private int track;
        EncodedOutput(File file) throws Exception { muxer = new MediaMuxer(file.getAbsolutePath(), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4); }
        void drain(MediaCodec codec, boolean end) {
            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
            long idleSince = System.nanoTime();
            while (true) {
                check();
                int index = codec.dequeueOutputBuffer(info, end ? 10000 : 0);
                if (index == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    if (!end) return;
                    if (System.nanoTime() - idleSince > 30_000_000_000L) throw new IllegalStateException("Encoder did not finish");
                } else if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    if (started) throw new IllegalStateException("Encoder format changed twice");
                    track = muxer.addTrack(codec.getOutputFormat()); muxer.start(); started = true;
                } else if (index >= 0) {
                    idleSince = System.nanoTime();
                    ByteBuffer data = codec.getOutputBuffer(index);
                    if ((info.flags & MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0) info.size = 0;
                    if (info.size > 0) { data.position(info.offset); data.limit(info.offset + info.size);
                        muxer.writeSampleData(track, data, info); }
                    boolean done = (info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0;
                    codec.releaseOutputBuffer(index, false); if (done) return;
                }
            }
        }
        @Override public void close() { try { if (started) muxer.stop(); } finally { muxer.release(); } }
    }
    private void mux(File video, File audio, File output) throws Exception {
        MediaExtractor v = new MediaExtractor(), a = new MediaExtractor();
        MediaMuxer muxer = new MediaMuxer(output.getAbsolutePath(), MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
        boolean started = false;
        try {
            v.setDataSource(video.getAbsolutePath()); a.setDataSource(audio.getAbsolutePath());
            int vt = muxer.addTrack(v.getTrackFormat(0)), at = muxer.addTrack(a.getTrackFormat(0));
            v.selectTrack(0); a.selectTrack(0); muxer.start(); started = true;
            ByteBuffer buffer = ByteBuffer.allocateDirect(16 * 1024 * 1024);
            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
            while (v.getSampleTime() >= 0 || a.getSampleTime() >= 0) {
                check();
                boolean useVideo = a.getSampleTime() < 0 || (v.getSampleTime() >= 0 && v.getSampleTime() <= a.getSampleTime());
                MediaExtractor input = useVideo ? v : a;
                buffer.clear(); int size = input.readSampleData(buffer, 0);
                if (size < 0) break;
                info.set(0, size, input.getSampleTime(), input.getSampleFlags());
                muxer.writeSampleData(useVideo ? vt : at, buffer, info); input.advance();
            }
        } finally { v.release(); a.release(); try { if (started) muxer.stop(); } finally { muxer.release(); } }
    }
    private void copy(File from, File to) throws Exception {
        try (FileInputStream in = new FileInputStream(from); FileOutputStream out = new FileOutputStream(to)) {
            byte[] data = new byte[65536]; int size;
            while ((size = in.read(data)) >= 0) { check(); out.write(data, 0, size); }
        }
    }
    private static void fail(MethodChannel.Result result, Throwable error) {
        result.error(error instanceof CancellationException ? "cancelled" : "export_failed",
            error.getMessage() == null ? error.toString() : error.getMessage(), null);
    }
    void close() {
        closed = cancelled = true; detach(); channel.setMethodCallHandler(null);
        if (pendingResult != null) { pendingResult.error("export_closed", "Export service was closed", null); pendingResult = null; }
        worker.execute(this::closePreview); worker.shutdown();
    }
}
