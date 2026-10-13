package dev.geode.geode_native;

import android.content.res.AssetManager;

/** Render-only native host. Each wallpaper or dream owns its own GL resources. */
final class GeodeAmbientBindings {
    static { System.loadLibrary("geode"); }
    static native long create(AssetManager assets, String cache, int width, int height);
    static native void render(long handle, double seconds);
    static native void scene(long handle, String id);
    static native void param(long handle, String name, float value);
    static native void reducedMotion(long handle, boolean enabled);
    static native void milk(long handle, String path);
    static native void touch(long handle, float x, float y, float dx, float dy, float dt, float strength);
    static native void close(long handle);
    private GeodeAmbientBindings() {}
}
