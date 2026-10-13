package dev.geode.geode_native;

import android.service.dreams.DreamService;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

/** Dock/charge screensaver with the same selected nature scene as the app. */
public final class GeodeDreamService extends DreamService implements SurfaceHolder.Callback {
    private GeodeAmbientRenderer renderer;
    private SurfaceView view;

    @Override public void onAttachedToWindow() {
        super.onAttachedToWindow();
        setInteractive(false);
        setFullscreen(true);
        setScreenBright(false);
        renderer = new GeodeAmbientRenderer(this);
        view = new SurfaceView(this);
        view.getHolder().addCallback(this);
        setContentView(view);
    }

    @Override public void onDreamingStarted() {
        super.onDreamingStarted();
        if (renderer != null) renderer.setVisible(true);
    }

    @Override public void onDreamingStopped() {
        if (renderer != null) renderer.setVisible(false);
        super.onDreamingStopped();
    }

    @Override public void onDetachedFromWindow() {
        if (view != null) view.getHolder().removeCallback(this);
        if (renderer != null) { renderer.clearSurface(); renderer.close(); renderer = null; }
        view = null;
        super.onDetachedFromWindow();
    }

    @Override public void surfaceCreated(SurfaceHolder holder) {}

    @Override public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        if (renderer != null) renderer.setSurface(holder.getSurface(), width, height);
    }

    @Override public void surfaceDestroyed(SurfaceHolder holder) {
        if (renderer != null) renderer.clearSurface();
    }
}
