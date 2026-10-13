package dev.geode.geode_native;

import android.content.Context;
import android.content.SharedPreferences;
import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLSurface;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.SystemClock;
import android.util.Log;
import android.view.Surface;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/** A serial EGL host for both Android system surfaces, independent of Flutter's texture. */
final class GeodeAmbientRenderer {
    private static final String TAG = "GeodeAmbient";
    private final Context application;
    private final SharedPreferences preferences;
    private final HandlerThread thread = new HandlerThread("Geode-Ambient-GLES");
    private final Handler gl;
    private EGLDisplay display = EGL14.EGL_NO_DISPLAY;
    private EGLContext context = EGL14.EGL_NO_CONTEXT;
    private EGLSurface surface = EGL14.EGL_NO_SURFACE;
    private long nativeHandle;
    private boolean visible;
    private boolean closed;
    private boolean preferencesDirty = true;
    private final SharedPreferences.OnSharedPreferenceChangeListener preferencesChanged =
            (ignored, key) -> markPreferencesDirty();

    GeodeAmbientRenderer(Context context) {
        application = context.getApplicationContext();
        preferences = GeodeAmbientPreferences.get(application);
        thread.start();
        gl = new Handler(thread.getLooper());
        preferences.registerOnSharedPreferenceChangeListener(preferencesChanged);
    }

    private void markPreferencesDirty() {
        gl.post(() -> preferencesDirty = true);
    }

    void setSurface(Surface target, int width, int height) {
        if (width < 1 || height < 1) return;
        gl.post(() -> {
            if (closed) return;
            releaseSurface();
            if (!target.isValid()) return;
            try {
                display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
                int[] version = new int[2];
                require(EGL14.eglInitialize(display, version, 0, version, 1), "initialize EGL");
                int[] attributes = {EGL14.EGL_RENDERABLE_TYPE, 0x40,
                        EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
                        EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8,
                        EGL14.EGL_BLUE_SIZE, 8, EGL14.EGL_ALPHA_SIZE, 8, EGL14.EGL_NONE};
                EGLConfig[] configs = new EGLConfig[1];
                int[] count = new int[1];
                require(EGL14.eglChooseConfig(display, attributes, 0, configs, 0, 1, count, 0)
                        && count[0] > 0, "choose OpenGL ES 3 configuration");
                context = EGL14.eglCreateContext(display, configs[0], EGL14.EGL_NO_CONTEXT,
                        new int[]{EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE}, 0);
                require(context != EGL14.EGL_NO_CONTEXT, "create OpenGL ES 3 context");
                surface = EGL14.eglCreateWindowSurface(display, configs[0], target,
                        new int[]{EGL14.EGL_NONE}, 0);
                require(surface != EGL14.EGL_NO_SURFACE, "create system surface");
                require(EGL14.eglMakeCurrent(display, surface, surface, context), "activate system surface");
                EGL14.eglSwapInterval(display, 1);
                nativeHandle = GeodeAmbientBindings.create(application.getAssets(),
                        application.getCacheDir().getAbsolutePath(), width, height);
                require(nativeHandle != 0, "create ambient renderer");
                preferencesDirty = true;
                scheduleFrame();
            } catch (RuntimeException | LinkageError error) {
                Log.e(TAG, "Could not initialize visualizer", error);
                releaseSurface();
            }
        });
    }

    void setVisible(boolean value) {
        gl.post(() -> {
            if (closed) return;
            visible = value;
            gl.removeCallbacks(frame);
            if (value) scheduleFrame();
        });
    }

    void touch(float x, float y, float dx, float dy, float dt, float strength) {
        gl.post(() -> {
            if (nativeHandle != 0 && visible && !closed) {
                GeodeAmbientBindings.touch(nativeHandle, x, y, dx, dy, dt, strength);
            }
        });
    }

    /** Android requires rendering to stop before its SurfaceHolder disappears. */
    void clearSurface() {
        CountDownLatch released = new CountDownLatch(1);
        gl.post(() -> {
            try { releaseSurface(); }
            finally { released.countDown(); }
        });
        try {
            if (!released.await(300, TimeUnit.MILLISECONDS)) {
                Log.w(TAG, "Surface release is still finishing on the GL thread");
            }
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
        }
    }

    void close() {
        preferences.unregisterOnSharedPreferenceChangeListener(preferencesChanged);
        gl.post(() -> {
            if (closed) return;
            closed = true;
            try { releaseSurface(); }
            finally { thread.quitSafely(); }
        });
    }

    private void scheduleFrame() {
        gl.removeCallbacks(frame);
        if (!closed && visible && nativeHandle != 0) gl.post(frame);
    }

    private final Runnable frame = new Runnable() {
        @Override public void run() {
            if (closed || !visible || nativeHandle == 0) return;
            long start = SystemClock.uptimeMillis();
            try {
                if (preferencesDirty) {
                    GeodeAmbientPreferences.apply(preferences, nativeHandle);
                    preferencesDirty = false;
                }
                GeodeAmbientBindings.render(nativeHandle, System.nanoTime() / 1_000_000_000.0);
                require(EGL14.eglSwapBuffers(display, surface), "present system visualizer");
                // Bound home-screen GPU use and reduce animation further when requested.
                int interval = preferences.getBoolean("reducedMotion", false) ? 67 : 33;
                gl.postDelayed(this, Math.max(1, interval - (SystemClock.uptimeMillis() - start)));
            } catch (RuntimeException | LinkageError error) {
                Log.e(TAG, "Ambient visualizer stopped after a rendering error", error);
                releaseSurface();
            }
        }
    };

    private void releaseSurface() {
        gl.removeCallbacks(frame);
        if (nativeHandle != 0) {
            try { GeodeAmbientBindings.close(nativeHandle); }
            catch (RuntimeException | LinkageError error) { Log.w(TAG, "Native renderer cleanup failed", error); }
            nativeHandle = 0;
        }
        if (display != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
            if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface);
            if (context != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, context);
            EGL14.eglTerminate(display);
            EGL14.eglReleaseThread();
        }
        display = EGL14.EGL_NO_DISPLAY;
        context = EGL14.EGL_NO_CONTEXT;
        surface = EGL14.EGL_NO_SURFACE;
        // Android owns the supplied Surface; only its EGL wrapper belongs here.
    }

    private static void require(boolean condition, String operation) {
        if (!condition) throw new IllegalStateException("Could not " + operation + " (EGL 0x"
                + Integer.toHexString(EGL14.eglGetError()) + ")");
    }
}
