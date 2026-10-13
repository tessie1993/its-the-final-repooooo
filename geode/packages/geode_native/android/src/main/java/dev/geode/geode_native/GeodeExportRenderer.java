package dev.geode.geode_native;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.opengl.EGL14;
import android.opengl.EGLExt;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLSurface;
import android.opengl.GLES30;
import android.view.Surface;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Shared composition renderer for scrubbing and frame-exact MP4 export. */
final class GeodeExportRenderer implements AutoCloseable {
    private final Context app;
    private final int width, height;
    private final Map<String, Object> project;
    private final List<Map<String, Object>> clips;
    private final Map<String, Bitmap> images = new HashMap<>();
    private final Map<String, MediaMetadataRetriever> videos = new HashMap<>();
    private final Bitmap overlay;
    private final int[] pixels;
    private final Canvas canvas;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
    private EGLDisplay display = EGL14.EGL_NO_DISPLAY;
    private EGLContext eglContext = EGL14.EGL_NO_CONTEXT;
    private EGLSurface surface = EGL14.EGL_NO_SURFACE;
    private long nativeHandle;

    GeodeExportRenderer(Context app, Map<String, Object> project, int width, int height,
            Surface target) throws Exception {
        this.app = app;
        this.project = project;
        this.width = width;
        this.height = height;
        clips = maps(project.get("clips"));
        clips.sort((a, b) -> Long.compare(number(a, "startMs", 0), number(b, "startMs", 0)));
        overlay = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        pixels = new int[width * height];
        canvas = new Canvas(overlay);
        try {
            display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
            int[] v = new int[2];
            require(EGL14.eglInitialize(display, v, 0, v, 1), "Initialize export EGL");
            int surfaceType = target == null ? EGL14.EGL_PBUFFER_BIT : EGL14.EGL_WINDOW_BIT;
            int[] attrs = {EGL14.EGL_RENDERABLE_TYPE, 0x40, EGL14.EGL_SURFACE_TYPE, surfaceType,
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8, 0x3142, 1, EGL14.EGL_NONE};
            EGLConfig[] config = new EGLConfig[1];
            int[] count = new int[1];
            require(EGL14.eglChooseConfig(display, attrs, 0, config, 0, 1, count, 0) && count[0] > 0,
                "Choose encoder EGL config");
            eglContext = EGL14.eglCreateContext(display, config[0], EGL14.EGL_NO_CONTEXT,
                new int[]{EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE}, 0);
            surface = target == null ? EGL14.eglCreatePbufferSurface(display, config[0],
                new int[]{EGL14.EGL_WIDTH, width, EGL14.EGL_HEIGHT, height, EGL14.EGL_NONE}, 0)
                : EGL14.eglCreateWindowSurface(display, config[0], target, new int[]{EGL14.EGL_NONE}, 0);
            require(eglContext != EGL14.EGL_NO_CONTEXT && surface != EGL14.EGL_NO_SURFACE,
                "Create export surface");
            require(EGL14.eglMakeCurrent(display, surface, surface, eglContext), "Activate export surface");
            nativeHandle = GeodeExportBindings.create(app.getAssets(), app.getCacheDir().getAbsolutePath(), width, height);
        } catch (Throwable error) { close(); throw error; }
    }

    void render(long atMs, float[] pcm, long presentationNs) throws Exception {
        require(EGL14.eglMakeCurrent(display, surface, surface, eglContext), "Activate renderer");
        overlay.eraseColor(Color.TRANSPARENT);
        Map<String, Object> visual = null;
        for (Map<String, Object> clip : clips) if (active(clip, atMs) && "visual".equals(clip.get("lane"))) visual = clip;
        String scene = visual == null ? "water" : new String[]{"water", "aurora", "voronoi"}[
            (int)Math.max(0, Math.min(2, number(visual, "materialIndex", 0)))];
        if (visual == null) canvas.drawColor(Color.rgb(12, 23, 16));
        else transition(visual, atMs, () -> {} , true);
        for (String lane : new String[]{"media", "overlay", "text"}) {
            for (Map<String, Object> clip : clips) {
                if (!lane.equals(clip.get("lane")) || !active(clip, atMs)) continue;
                final Map<String, Object> item = clip;
                if ("text".equals(lane)) transition(item, atMs, () -> drawText(item), false);
                else {
                    Bitmap image = image(item, atMs);
                    transition(item, atMs, () -> drawImage(image, "overlay".equals(lane)), false);
                    if (videos.containsKey(String.valueOf(item.get("source"))) && image != null) image.recycle();
                }
            }
        }
        float opacity = evaluate(project, "opacity", atMs, 1);
        if (opacity < 1) canvas.drawColor(Color.argb(Math.round((1 - opacity) * 255), 0, 0, 0));
        overlay.getPixels(pixels, 0, width, 0, 0, width, height);
        GeodeExportBindings.frame(nativeHandle, scene, atMs / 1000.0,
            evaluate(project, "energy", atMs, 1), pcm, pixels, width, height);
        if (presentationNs >= 0) {
            EGLExt.eglPresentationTimeANDROID(display, surface, presentationNs);
            require(EGL14.eglSwapBuffers(display, surface), "Write encoded frame");
        }
    }

    byte[] png() {
        ByteBuffer data = ByteBuffer.allocateDirect(width * height * 4).order(ByteOrder.nativeOrder());
        GLES30.glReadPixels(0, 0, width, height, GLES30.GL_RGBA, GLES30.GL_UNSIGNED_BYTE, data);
        int[] colors = new int[width * height];
        for (int y = 0; y < height; y++) for (int x = 0; x < width; x++) {
            int i = (y * width + x) * 4;
            colors[(height - 1 - y) * width + x] = Color.argb(data.get(i + 3) & 255,
                data.get(i) & 255, data.get(i + 1) & 255, data.get(i + 2) & 255);
        }
        Bitmap bitmap = Bitmap.createBitmap(colors, width, height, Bitmap.Config.ARGB_8888);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out);
        bitmap.recycle();
        return out.toByteArray();
    }

    private boolean active(Map<String, Object> clip, long at) {
        Map<String, Object> lane = map(map(project.get("lanes")).get(clip.get("lane")));
        long start = number(clip, "startMs", 0);
        return !Boolean.FALSE.equals(clip.get("enabled")) && !Boolean.TRUE.equals(lane.get("muted"))
            && at >= start && at < start + number(clip, "durationMs", 4000);
    }

    private void transition(Map<String, Object> clip, long at, Runnable draw, boolean nativeLayer) {
        Map<String, Object> settings = map(clip.get("transition"));
        String type = String.valueOf(settings.get("type"));
        long duration = number(settings, "durationMs", 0);
        float progress = duration <= 0 ? 1 : Math.min(1, (at - number(clip, "startMs", 0)) / (float)duration);
        int save = canvas.save();
        if (nativeLayer && progress < 1 && !"none".equals(type)) {
            paint.setColor(Color.BLACK);
            paint.setAlpha("wipe".equals(type) ? 255 : Math.round((1 - progress) * 255));
            canvas.drawRect("wipe".equals(type) ? width * progress : 0, 0, width, height, paint);
        } else {
            if ("wipe".equals(type)) canvas.clipRect(0, 0, width * progress, height);
            if (("fade".equals(type) || "dissolve".equals(type)) && progress < 1)
                canvas.saveLayerAlpha(0, 0, width, height, Math.round(progress * 255));
            draw.run();
        }
        canvas.restoreToCount(save);
        paint.setAlpha(255);
    }

    private Bitmap image(Map<String, Object> clip, long atMs) throws Exception {
        String path = String.valueOf(clip.get("source"));
        if (images.containsKey(path)) return images.get(path);
        if (!videos.containsKey(path)) {
            try (InputStream input = app.getContentResolver().openInputStream(Uri.parse(path))) {
                BitmapFactory.Options bounds = new BitmapFactory.Options(); bounds.inJustDecodeBounds = true;
                BitmapFactory.decodeStream(input, null, bounds);
                if (bounds.outWidth > 0) {
                    BitmapFactory.Options options = new BitmapFactory.Options();
                    options.inSampleSize = Math.max(1, Math.max(bounds.outWidth / width, bounds.outHeight / height));
                    try (InputStream stream = app.getContentResolver().openInputStream(Uri.parse(path))) {
                        Bitmap result = BitmapFactory.decodeStream(stream, null, options);
                        if (result == null) throw new IllegalArgumentException("Cannot read image " + path);
                        images.put(path, result); return result;
                    }
                }
            }
            MediaMetadataRetriever retriever = new MediaMetadataRetriever();
            try { retriever.setDataSource(app, Uri.parse(path)); videos.put(path, retriever); }
            catch (Exception error) { retriever.release(); throw error; }
        }
        long sourceMs = number(clip, "sourceInMs", 0) + atMs - number(clip, "startMs", 0);
        Bitmap result = videos.get(path).getScaledFrameAtTime(sourceMs * 1000,
            MediaMetadataRetriever.OPTION_CLOSEST, width, height);
        if (result == null) throw new IllegalArgumentException("Cannot decode video frame: " + path);
        return result;
    }

    private void drawImage(Bitmap image, boolean contain) {
        if (image == null) return;
        float scale = contain ? Math.min(width / (float)image.getWidth(), height / (float)image.getHeight())
            : Math.max(width / (float)image.getWidth(), height / (float)image.getHeight());
        float w = image.getWidth() * scale, h = image.getHeight() * scale;
        paint.setAlpha(255);
        canvas.drawBitmap(image, null, new RectF((width - w) / 2, (height - h) / 2,
            (width + w) / 2, (height + h) / 2), paint);
    }

    private void drawText(Map<String, Object> clip) {
        paint.setColor(Color.rgb(247, 244, 225));
        paint.setTextSize(Math.min(width, height) * .064f);
        paint.setTextAlign(Paint.Align.CENTER);
        paint.setTypeface(android.graphics.Typeface.create("sans-serif-medium", 0));
        paint.setShadowLayer(5, 1, 2, Color.BLACK);
        List<String> lines = new ArrayList<>();
        for (String paragraph : String.valueOf(clip.get("label")).split("\n")) {
            String line = "";
            for (String word : paragraph.split(" ")) {
                String next = line.isEmpty() ? word : line + " " + word;
                if (paint.measureText(next) > width * .86f && !line.isEmpty()) { lines.add(line); line = word; }
                else line = next;
            }
            lines.add(line);
        }
        float lineHeight = paint.getTextSize() * 1.25f;
        float y = height / 2f - (lines.size() - 1) * lineHeight / 2 - (paint.ascent() + paint.descent()) / 2;
        for (String line : lines) { canvas.drawText(line, width / 2f, y, paint); y += lineHeight; }
        paint.clearShadowLayer();
    }

    static float evaluate(Map<String, Object> project, String parameter, long at, float fallback) {
        List<Map<String, Object>> keys = maps(project.get("keys"));
        keys.removeIf(key -> !parameter.equals(key.get("parameter")));
        keys.sort((a, b) -> Long.compare(number(a, "atMs", 0), number(b, "atMs", 0)));
        if (keys.isEmpty()) return fallback;
        Map<String, Object> previous = keys.get(0);
        for (Map<String, Object> key : keys) {
            if (at <= number(key, "atMs", 0)) {
                long start = number(previous, "atMs", 0), end = number(key, "atMs", 0);
                float from = ((Number)previous.get("value")).floatValue(), to = ((Number)key.get("value")).floatValue();
                return end <= start ? to : from + (to - from) * Math.max(0, (at - start) / (float)(end - start));
            }
            previous = key;
        }
        return ((Number)previous.get("value")).floatValue();
    }

    @SuppressWarnings("unchecked") static Map<String, Object> map(Object value) {
        return value instanceof Map ? (Map<String, Object>)value : new HashMap<>();
    }
    static List<Map<String, Object>> maps(Object value) {
        List<Map<String, Object>> result = new ArrayList<>();
        if (value instanceof List) for (Object item : (List<?>)value) result.add(map(item));
        return result;
    }
    static long number(Map<String, Object> map, String key, long fallback) {
        Object n = map.get(key); return n instanceof Number ? ((Number)n).longValue() : fallback;
    }
    private static void require(boolean value, String label) {
        if (!value) throw new IllegalStateException(label + " (EGL " + EGL14.eglGetError() + ")");
    }
    @Override public void close() {
        if (display != EGL14.EGL_NO_DISPLAY && surface != EGL14.EGL_NO_SURFACE)
            EGL14.eglMakeCurrent(display, surface, surface, eglContext);
        if (nativeHandle != 0) { GeodeExportBindings.close(nativeHandle); nativeHandle = 0; }
        for (Bitmap bitmap : images.values()) bitmap.recycle();
        for (MediaMetadataRetriever retriever : videos.values()) {
            try { retriever.release(); } catch (Exception ignored) {}
        }
        overlay.recycle();
        if (display != EGL14.EGL_NO_DISPLAY) {
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT);
            if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface);
            if (eglContext != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, eglContext);
            EGL14.eglTerminate(display);
            EGL14.eglReleaseThread();
        }
    }
}
