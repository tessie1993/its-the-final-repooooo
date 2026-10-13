package dev.geode.geode_native;

import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;

/** A foreground-only microphone tap. Raw PCM goes straight to the C++ ring. */
final class GeodeAudioInput {
    private final long session;
    private AudioRecord recorder;
    private Thread worker;
    private volatile boolean running;

    GeodeAudioInput(long session) { this.session = session; }

    void start() {
        if (running) return;
        final int sampleRate = 48000;
        int minimum = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_FLOAT);
        if (minimum <= 0) throw new IllegalStateException("Microphone PCM capture is unavailable");
        recorder = new AudioRecord.Builder()
                .setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
                .setAudioFormat(new AudioFormat.Builder().setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                        .setEncoding(AudioFormat.ENCODING_PCM_FLOAT).build())
                .setBufferSizeInBytes(Math.max(minimum * 2, 16384)).build();
        if (recorder.getState() != AudioRecord.STATE_INITIALIZED) {
            recorder.release();
            recorder = null;
            throw new IllegalStateException("Could not initialize the microphone");
        }
        try {
            recorder.startRecording();
            if (recorder.getRecordingState() != AudioRecord.RECORDSTATE_RECORDING)
                throw new IllegalStateException("Microphone access is blocked by the system");
            NativeBindings.inputRate(session, sampleRate);
            running = true;
            AudioRecord source = recorder;
            worker = new Thread(() -> {
                float[] pcm = new float[1024];
                while (running) {
                    int count = source.read(pcm, 0, pcm.length, AudioRecord.READ_BLOCKING);
                    if (count < 0) break;
                    if (running && count > 0) NativeBindings.inputPcm(session, pcm, count);
                }
            }, "Geode-Microphone");
            worker.start();
        } catch (RuntimeException error) {
            recorder.release();
            recorder = null;
            throw error;
        }
    }

    void stop() {
        running = false;
        if (recorder != null) {
            try { recorder.stop(); } catch (IllegalStateException ignored) {}
            if (worker != null) {
                // stop() unblocks AudioRecord.read. Join before the owning native
                // session can be destroyed, preventing a late JNI call after free.
                boolean interrupted = false;
                while (worker.isAlive()) {
                    try { worker.join(); } catch (InterruptedException error) { interrupted = true; }
                }
                if (interrupted) Thread.currentThread().interrupt();
            }
            recorder.release();
            recorder = null;
            worker = null;
        }
        NativeBindings.inputRate(session, 0);
    }
}
