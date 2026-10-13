package dev.geode.geode_native;

import android.service.wallpaper.WallpaperService;
import android.view.MotionEvent;
import android.view.SurfaceHolder;

/** Live nature scenes powered by the original native visualizer and playback PCM. */
public final class GeodeWallpaperService extends WallpaperService {
    @Override public Engine onCreateEngine() { return new NatureEngine(); }

    private final class NatureEngine extends Engine {
        private GeodeAmbientRenderer renderer;
        private int width = 1;
        private int height = 1;
        private float previousX;
        private float previousY;
        private long previousTime;

        @Override public void onCreate(SurfaceHolder holder) {
            super.onCreate(holder);
            setTouchEventsEnabled(true);
            renderer = new GeodeAmbientRenderer(GeodeWallpaperService.this);
        }

        @Override public void onSurfaceChanged(SurfaceHolder holder, int format, int w, int h) {
            super.onSurfaceChanged(holder, format, w, h);
            width = Math.max(1, w);
            height = Math.max(1, h);
            if (renderer != null) renderer.setSurface(holder.getSurface(), width, height);
        }

        @Override public void onVisibilityChanged(boolean visible) {
            super.onVisibilityChanged(visible);
            previousTime = 0;
            if (renderer != null) renderer.setVisible(visible);
        }

        @Override public void onTouchEvent(MotionEvent event) {
            super.onTouchEvent(event);
            if (renderer == null) return;
            int action = event.getActionMasked();
            if (action == MotionEvent.ACTION_CANCEL || action == MotionEvent.ACTION_UP) {
                previousTime = 0;
                return;
            }
            float x = Math.max(0f, Math.min(1f, event.getX() / width));
            float y = Math.max(0f, Math.min(1f, event.getY() / height));
            long now = event.getEventTime();
            boolean first = previousTime == 0 || action == MotionEvent.ACTION_DOWN;
            float dt = first ? .016f : Math.max(.001f, Math.min(1f, (now - previousTime) / 1000f));
            renderer.touch(x, y, first ? 0 : x - previousX, first ? 0 : y - previousY, dt, .55f);
            previousX = x;
            previousY = y;
            previousTime = now;
        }

        @Override public void onSurfaceDestroyed(SurfaceHolder holder) {
            if (renderer != null) renderer.clearSurface();
            super.onSurfaceDestroyed(holder);
        }

        @Override public void onDestroy() {
            if (renderer != null) { renderer.close(); renderer = null; }
            super.onDestroy();
        }
    }
}
