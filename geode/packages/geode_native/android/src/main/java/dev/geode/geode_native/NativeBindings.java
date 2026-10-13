package dev.geode.geode_native;

import android.content.res.AssetManager;

/** Narrow JNI contract. No PCM buffers cross the Flutter platform channel. */
final class NativeBindings {
    static { System.loadLibrary("geode"); }
    private NativeBindings() {}

    static native long create(AssetManager assets, String cache);
    static native void destroy(long handle);
    static native void open(long handle, int fd, long offset, long length, long token, boolean next);
    static native void command(long handle, int command, long value, double extra);
    static native long[] snapshot(long handle);
    static native float[] features(long handle);
    static native String error(long handle);
    static native void surfaceCreated(long handle, int width, int height);
    static native void surfaceDestroyed(long handle);
    static native void render(long handle, double time);
    static native boolean scene(long handle, String id);
    static native boolean param(long handle, String name, double value);
    static native void reducedMotion(long handle, boolean on);
    static native void milk(long handle, String path);
    static native void milkTextures(long handle, String path);
    static native String scenes(long handle);
    static native void touch(long handle, float x, float y, float dx, float dy, float dt, float strength);
    static native java.util.Map<String, Object> readTags(int fd);
    static native void inputRate(long handle, int sampleRate);
    static native void inputPcm(long handle, float[] mono, int count);
    static native void equalizer(long handle, float[] config);
}
