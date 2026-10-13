package dev.geode.geode_native;

import android.app.Activity;
import android.app.WallpaperManager;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.provider.Settings;

/** Explicit Android chooser actions launched from the app's settings. */
final class GeodeAmbientActions {
    private GeodeAmbientActions() {}

    static void setWallpaper(Activity activity) {
        requireActivity(activity);
        Intent intent = new Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER)
                .putExtra(WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                        new ComponentName(activity, GeodeWallpaperService.class));
        if (intent.resolveActivity(activity.getPackageManager()) == null) {
            intent = new Intent(WallpaperManager.ACTION_LIVE_WALLPAPER_CHOOSER);
        }
        activity.startActivity(intent);
    }

    static void openScreensaverSettings(Activity activity) {
        requireActivity(activity);
        activity.startActivity(new Intent(Settings.ACTION_DREAM_SETTINGS));
    }

    static boolean requestPinWidget(Context context) {
        AppWidgetManager manager = AppWidgetManager.getInstance(context);
        if (!manager.isRequestPinAppWidgetSupported()) return false;
        return manager.requestPinAppWidget(
                new ComponentName(context, GeodeNowPlayingWidget.class), null, null);
    }

    private static void requireActivity(Activity activity) {
        if (activity == null) throw new IllegalStateException("Open Geode before changing system appearance");
    }
}
