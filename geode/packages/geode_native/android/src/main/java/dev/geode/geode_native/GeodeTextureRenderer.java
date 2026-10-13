package dev.geode.geode_native;

import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLSurface;
import android.os.Handler;
import android.os.HandlerThread;
import android.view.Surface;
import io.flutter.view.TextureRegistry;
import java.util.function.Consumer;

/** Owns EGL and every GL-thread-only engine call for a Flutter texture. */
final class GeodeTextureRenderer {
    private final long session;
    private final TextureRegistry.SurfaceTextureEntry texture;
    private final HandlerThread thread = new HandlerThread("Geode-GLES");
    private final Handler main;
    private final Consumer<Throwable> onError;
    private Handler gl;
    private Surface surface;
    private EGLDisplay display = EGL14.EGL_NO_DISPLAY;
    private EGLContext context = EGL14.EGL_NO_CONTEXT;
    private EGLSurface eglSurface = EGL14.EGL_NO_SURFACE;
    private boolean ready;
    private boolean closed;
    private boolean paused;
    private boolean visible = true;
    private boolean sceneCreated;

    GeodeTextureRenderer(long session, TextureRegistry registry, Handler main, Consumer<Throwable> onError) {
        this.session = session;
        this.texture = registry.createSurfaceTexture();
        this.main = main;
        this.onError = onError;
    }

    long id() { return texture.id(); }

    void start(int width, int height, Runnable onReady) {
        texture.surfaceTexture().setDefaultBufferSize(width, height);
        surface = new Surface(texture.surfaceTexture());
        thread.start();
        gl = new Handler(thread.getLooper());
        gl.post(() -> {
            try {
                display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
                int[] version = new int[2];
                require(EGL14.eglInitialize(display, version, 0, version, 1), "initialize EGL");
                int[] attributes = {EGL14.EGL_RENDERABLE_TYPE, 0x40, EGL14.EGL_SURFACE_TYPE, EGL14.EGL_WINDOW_BIT,
                    EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
                    EGL14.EGL_ALPHA_SIZE, 8, EGL14.EGL_NONE};
                EGLConfig[] configs = new EGLConfig[1];
                int[] count = new int[1];
                require(EGL14.eglChooseConfig(display, attributes, 0, configs, 0, 1, count, 0) && count[0] > 0,
                    "choose OpenGL ES 3 config");
                context = EGL14.eglCreateContext(display, configs[0], EGL14.EGL_NO_CONTEXT,
                    new int[]{EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE}, 0);
                require(context != EGL14.EGL_NO_CONTEXT, "create OpenGL ES 3 context");
                eglSurface = EGL14.eglCreateWindowSurface(display, configs[0], surface,
                    new int[]{EGL14.EGL_NONE}, 0);
                require(eglSurface != EGL14.EGL_NO_SURFACE, "create texture surface");
                require(EGL14.eglMakeCurrent(display, eglSurface, eglSurface, context), "activate EGL context");
                EGL14.eglSwapInterval(display, 0);
                NativeBindings.surfaceCreated(session, width, height);
                sceneCreated = true;
                ready = true;
                main.post(onReady);
                gl.post(frame);
            } catch (Throwable failure) {
                main.post(() -> onError.accept(failure));
            }
        });
    }

    private final Runnable frame = new Runnable() {
        @Override public void run() {
            if (closed || !ready) return;
            if (!paused && visible) {
                try {
                    NativeBindings.render(session, System.nanoTime() / 1_000_000_000.0);
                    require(EGL14.eglSwapBuffers(display, eglSurface), "present texture frame");
                } catch (Throwable failure) {
                    ready = false;
                    main.post(() -> onError.accept(failure));
                    return;
                }
            }
            gl.postDelayed(this, 16);
        }
    };

    void submit(Runnable action, Runnable success, Consumer<Throwable> error) {
        gl.post(() -> {
            try {
                if (closed || !ready) throw new IllegalStateException("Visualizer surface is unavailable");
                action.run();
                main.post(success);
            } catch (Throwable failure) { main.post(() -> error.accept(failure)); }
        });
    }

    void setPaused(boolean value) { gl.post(() -> paused = value); }
    void setVisible(boolean value) { gl.post(() -> visible = value); }

    void close(Runnable complete) {
        gl.post(() -> {
            closed = true;
            gl.removeCallbacks(frame);
            if (sceneCreated) NativeBindings.surfaceDestroyed(session);
            if (display != EGL14.EGL_NO_DISPLAY) {
                EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
                if (eglSurface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, eglSurface);
                if (context != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, context);
                EGL14.eglTerminate(display);
                EGL14.eglReleaseThread();
            }
            surface.release();
            thread.quitSafely();
            main.post(() -> { texture.release(); complete.run(); });
        });
    }

    private static void require(boolean condition, String operation) {
        if (!condition) throw new IllegalStateException("Could not " + operation + " (EGL 0x" +
            Integer.toHexString(EGL14.eglGetError()) + ")");
    }
}
