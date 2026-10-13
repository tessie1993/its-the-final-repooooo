package dev.geode.geode_native;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.widget.RemoteViews;
import java.io.File;
import java.util.Map;

/** Nature-themed launcher transport backed by the player's real Android service. */
public final class GeodeNowPlayingWidget extends AppWidgetProvider {
    private static final String FILE = "geode_widget";
    private static final String ACTION_PREFIX = "dev.geode.geode_native.playback.";
    // Persisted metadata may survive a killed process; transport must not claim its queue does.
    private static boolean livePlayer;

    static void update(Context context, Map<?, ?> state) {
        if (state == null || Boolean.FALSE.equals(state.get("hasMedia"))) {
            clear(context);
            return;
        }
        SharedPreferences preferences = context.getSharedPreferences(FILE, Context.MODE_PRIVATE);
        String title = text(state, "title");
        String artist = text(state, "artist");
        String artPath = text(state, "artPath");
        if (artPath.isEmpty()) artPath = text(state, "artUri");
        boolean playing = Boolean.TRUE.equals(state.get("playing"));
        boolean changed = !livePlayer || !title.equals(preferences.getString("title", ""))
                || !artist.equals(preferences.getString("artist", ""))
                || !artPath.equals(preferences.getString("art", ""))
                || playing != preferences.getBoolean("playing", false);
        livePlayer = true;
        if (!changed) return;
        preferences.edit().putString("title", title).putString("artist", artist)
                .putString("art", artPath).putBoolean("playing", playing).apply();
        refresh(context);
    }

    static void clear(Context context) {
        livePlayer = false;
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit()
                .putBoolean("playing", false).apply();
        refresh(context);
    }

    private static void refresh(Context context) {
        AppWidgetManager manager = AppWidgetManager.getInstance(context);
        int[] ids = manager.getAppWidgetIds(new ComponentName(context, GeodeNowPlayingWidget.class));
        if (ids.length > 0) manager.updateAppWidget(ids, views(context));
    }

    @Override public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
        manager.updateAppWidget(ids, views(context));
    }

    private static RemoteViews views(Context context) {
        SharedPreferences preferences = context.getSharedPreferences(FILE, Context.MODE_PRIVATE);
        boolean playing = livePlayer && preferences.getBoolean("playing", false);
        String title = preferences.getString("title", "");
        String artist = livePlayer ? preferences.getString("artist", "")
                : context.getString(R.string.geode_widget_open);
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.geode_now_playing_widget);
        views.setTextViewText(R.id.geode_widget_title,
                title == null || title.isEmpty() ? context.getString(R.string.geode_widget_title) : title);
        views.setTextViewText(R.id.geode_widget_artist, artist);
        views.setImageViewResource(R.id.geode_widget_play,
                playing ? R.drawable.geode_widget_pause : R.drawable.geode_widget_play);
        views.setContentDescription(R.id.geode_widget_play, context.getString(
                playing ? R.string.geode_widget_pause : R.string.geode_widget_play));
        Bitmap artwork = artwork(preferences.getString("art", ""));
        if (artwork == null) views.setImageViewResource(R.id.geode_widget_art, R.drawable.geode_nature_leaf);
        else views.setImageViewBitmap(R.id.geode_widget_art, artwork);
        PendingIntent launch = launchIntent(context);
        if (launch != null) views.setOnClickPendingIntent(R.id.geode_widget_root, launch);
        views.setOnClickPendingIntent(R.id.geode_widget_previous,
                livePlayer ? transport(context, "previous") : launch);
        views.setOnClickPendingIntent(R.id.geode_widget_play,
                livePlayer ? transport(context, playing ? "pause" : "play") : launch);
        views.setOnClickPendingIntent(R.id.geode_widget_next,
                livePlayer ? transport(context, "next") : launch);
        return views;
    }

    private static PendingIntent transport(Context context, String command) {
        Intent intent = new Intent(context, GeodePlaybackService.class).setAction(ACTION_PREFIX + command);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE;
        return "play".equals(command)
                ? PendingIntent.getForegroundService(context, command.hashCode(), intent, flags)
                : PendingIntent.getService(context, command.hashCode(), intent, flags);
    }

    private static PendingIntent launchIntent(Context context) {
        Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (intent == null) return null;
        intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        return PendingIntent.getActivity(context, 7302, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private static Bitmap artwork(String value) {
        if (value == null || value.isEmpty()) return null;
        Uri uri = Uri.parse(value);
        if (uri.getScheme() != null && !"file".equals(uri.getScheme())) return null;
        String path = uri.getScheme() == null ? value : uri.getPath();
        if (path == null || !new File(path).isFile()) return null;
        BitmapFactory.Options bounds = new BitmapFactory.Options();
        bounds.inJustDecodeBounds = true;
        BitmapFactory.decodeFile(path, bounds);
        if (bounds.outWidth < 1 || bounds.outHeight < 1) return null;
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inSampleSize = 1;
        while (Math.max(bounds.outWidth, bounds.outHeight) / options.inSampleSize > 192) options.inSampleSize *= 2;
        return BitmapFactory.decodeFile(path, options);
    }

    private static String text(Map<?, ?> state, String key) {
        Object value = state.get(key);
        return value instanceof String ? (String) value : "";
    }
}
