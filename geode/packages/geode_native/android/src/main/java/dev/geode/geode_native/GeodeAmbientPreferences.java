package dev.geode.geode_native;

import android.content.Context;
import android.content.SharedPreferences;
import java.io.File;
import java.util.Map;

/** Last working live scene, shared with the wallpaper and screensaver. */
final class GeodeAmbientPreferences {
    private static final String FILE = "geode_ambient";
    private static final String PARAM_PREFIX = "param.";
    private GeodeAmbientPreferences() {}

    static SharedPreferences get(Context context) {
        return context.getSharedPreferences(FILE, Context.MODE_PRIVATE);
    }

    static void rememberScene(Context context, String id) {
        get(context).edit().putString("scene", id).apply();
    }

    static void rememberParam(Context context, String name, float value) {
        if (Float.isFinite(value)) get(context).edit().putFloat(PARAM_PREFIX + name, value).apply();
    }

    static void rememberReducedMotion(Context context, boolean enabled) {
        get(context).edit().putBoolean("reducedMotion", enabled).apply();
    }

    static void rememberMilk(Context context, String path) {
        get(context).edit().putString("milk", path).apply();
    }

    /** Only called while the owning ambient renderer's GL context is current. */
    static void apply(SharedPreferences preferences, long handle) {
        GeodeAmbientBindings.scene(handle, preferences.getString("scene", "aurora"));
        for (Map.Entry<String, ?> entry : preferences.getAll().entrySet()) {
            if (entry.getKey().startsWith(PARAM_PREFIX) && entry.getValue() instanceof Float) {
                GeodeAmbientBindings.param(handle, entry.getKey().substring(PARAM_PREFIX.length()),
                        (Float) entry.getValue());
            }
        }
        GeodeAmbientBindings.reducedMotion(handle, preferences.getBoolean("reducedMotion", false));
        String milk = preferences.getString("milk", "");
        if (milk != null && !milk.isEmpty() && new File(milk).isFile()) {
            GeodeAmbientBindings.milk(handle, milk);
        }
    }
}
