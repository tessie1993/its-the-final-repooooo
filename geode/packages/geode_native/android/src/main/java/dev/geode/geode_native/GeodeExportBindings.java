package dev.geode.geode_native;

import android.content.res.AssetManager;

/** A separate offline renderer: exporting never changes the live player's state. */
final class GeodeExportBindings {
    static { System.loadLibrary("geode"); }
    static native long create(AssetManager assets, String cache, int width, int height);
    static native void frame(long handle, String scene, double seconds, float energy,
        float[] stereo, int[] overlay, int width, int height);
    static native void close(long handle);
    private GeodeExportBindings() {}
}
