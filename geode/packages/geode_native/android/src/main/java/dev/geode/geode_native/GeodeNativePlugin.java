package dev.geode.geode_native;

import android.app.Activity;
import android.app.Application;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.res.AssetFileDescriptor;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelFileDescriptor;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.view.TextureRegistry;
import java.io.File;
import java.io.IOException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Flutter owns controls; the original C++ engine owns decode, DSP, analysis and rendering. */
public final class GeodeNativePlugin implements FlutterPlugin, MethodChannel.MethodCallHandler,
        ActivityAware, Application.ActivityLifecycleCallbacks {
    private final Handler main = new Handler(Looper.getMainLooper());
    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private Context context;
    private TextureRegistry textures;
    private MethodChannel methods;
    private EventChannel playbackEvents;
    private EventChannel featureEvents;
    private EventChannel mediaEvents;
    private EventChannel.EventSink mediaSink;
    private EventChannel.EventSink playbackSink;
    private EventChannel.EventSink featureSink;
    private AudioManager audio;
    private AudioFocusRequest focus;
    private Activity activity;
    private long handle;
    private long requestedToken = -1;
    private GeodeTextureRenderer renderer;
    private boolean closingTexture;
    private boolean resumeOnFocus;
    private double volume = 1.0;
    private String visualizerError = "";
    private int pollCount;

    @Override public void onAttachedToEngine(FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        textures = binding.getTextureRegistry();
        methods = new MethodChannel(binding.getBinaryMessenger(), "geode_native");
        methods.setMethodCallHandler(this);
        playbackEvents = new EventChannel(binding.getBinaryMessenger(), "geode_native/playback");
        featureEvents = new EventChannel(binding.getBinaryMessenger(), "geode_native/features");
        playbackEvents.setStreamHandler(streamHandler(false));
        featureEvents.setStreamHandler(streamHandler(true));
        mediaEvents = new EventChannel(binding.getBinaryMessenger(), "geode_native/media_actions");
        mediaEvents.setStreamHandler(new EventChannel.StreamHandler() {
            @Override public void onListen(Object arguments, EventChannel.EventSink sink) { mediaSink = sink; }
            @Override public void onCancel(Object arguments) { mediaSink = null; }
        });
        GeodePlaybackService.attach(context, this::transport);
        audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        focus = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(new AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
            .setOnAudioFocusChangeListener(this::focusChanged, main).build();
        context.registerReceiver(noisy, new IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY));
        ((Application) context).registerActivityLifecycleCallbacks(this);
        main.post(poll);
    }

    private EventChannel.StreamHandler streamHandler(boolean features) {
        return new EventChannel.StreamHandler() {
            @Override public void onListen(Object arguments, EventChannel.EventSink sink) {
                if (features) featureSink = sink; else playbackSink = sink;
            }
            @Override public void onCancel(Object arguments) {
                if (features) featureSink = null; else playbackSink = null;
            }
        };
    }

    private final Runnable poll = new Runnable() {
        @Override public void run() {
            if (handle != 0) {
                if (featureSink != null) {
                    float[] frame = NativeBindings.features(handle);
                    if (frame != null) featureSink.success(frame);
                }
                if (++pollCount % 3 == 0 && playbackSink != null) playbackSink.success(snapshot());
            }
            main.postDelayed(this, 33);
        }
    };

    private Map<String, Object> snapshot() {
        long[] data = NativeBindings.snapshot(handle);
        Map<String, Object> result = new HashMap<>();
        result.put("state", data[0]);
        result.put("playing", data[1] != 0);
        result.put("positionMs", data[2]);
        result.put("durationMs", data[3]);
        // The core clears its current deck on decoder failure; retain the open
        // request identity so the Dart load Future can report that failure.
        result.put("token", data[0] == 4 && data[4] < 0 ? requestedToken : data[4]);
        result.put("sampleRate", data[5]);
        result.put("error", NativeBindings.error(handle));
        result.put("visualizerError", visualizerError);
        return result;
    }

    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        try {
            if (call.method.equals("initialize")) {
                if (handle == 0) handle = NativeBindings.create(context.getAssets(), context.getCacheDir().getAbsolutePath());
                result.success(null);
                return;
            }
            if (handle == 0) throw new IllegalStateException("Initialize the native engine first");
            switch (call.method) {
                case "open": case "setNext": open(call, result); return;
                case "readTags": readTags(requiredString(call, "uri"), result); return;
                case "publishPlaybackState":
                    GeodePlaybackService.update(context, (Map<?, ?>) call.arguments); break;
                case "play": play(); break;
                case "pause": pause(); break;
                case "stop": NativeBindings.command(handle, 2, 0, 0); abandonFocus(); break;
                case "seek": NativeBindings.command(handle, 3, number(call, "positionMs", 0).longValue(), 0); break;
                case "setVolume":
                    volume = Math.max(0, Math.min(1, finite(number(call, "volume", 1).doubleValue())));
                    NativeBindings.command(handle, 4, 0, volume); break;
                case "setCrossfade": NativeBindings.command(handle, 5,
                    number(call, "durationMs", 0).longValue(), number(call, "curve", 1).doubleValue()); break;
                case "snapshot": result.success(snapshot()); return;
                case "createTexture": createTexture(call, result); return;
                case "disposeTexture": closeTexture(() -> result.success(null)); return;
                case "setScene":
                    String id = requiredString(call, "id");
                    if (!Arrays.asList(NativeBindings.scenes(handle).split("\n")).contains(id))
                        throw new IllegalArgumentException("Unknown scene: " + id);
                    if (renderer == null) NativeBindings.scene(handle, id);
                    else {
                        renderer.submit(() -> {
                            if (!NativeBindings.scene(handle, id)) throw new IllegalStateException("Cannot load scene " + id);
                        }, () -> result.success(null), error -> failure(result, error));
                        return;
                    }
                    break;
                case "setParam":
                    if (!NativeBindings.param(handle, requiredString(call, "name"), finite(number(call, "value", 0).doubleValue())))
                        throw new IllegalArgumentException("Unknown visualization parameter");
                    break;
                case "setReducedMotion": NativeBindings.reducedMotion(handle, Boolean.TRUE.equals(call.argument("enabled"))); break;
                case "setPaused": if (renderer != null) renderer.setPaused(Boolean.TRUE.equals(call.argument("paused"))); break;
                case "listScenes": result.success(Arrays.asList(NativeBindings.scenes(handle).split("\n"))); return;
                case "listMilkPresets": io.execute(() -> {
                    try { List<String> presets = MilkAssets.presets(context); main.post(() -> result.success(presets)); }
                    catch (Exception error) { main.post(() -> failure(result, error)); }
                }); return;
                case "loadMilkPreset": loadMilkPreset(requiredString(call, "name"), result); return;
                case "setEqualizer": equalizer(call); break;
                case "touch": NativeBindings.touch(handle,
                    number(call, "x", 0).floatValue(), number(call, "y", 0).floatValue(),
                    number(call, "dx", 0).floatValue(), number(call, "dy", 0).floatValue(),
                    number(call, "dt", 0.016).floatValue(), number(call, "strength", 1).floatValue()); break;
                default: result.notImplemented(); return;
            }
            result.success(null);
        } catch (Throwable error) { failure(result, error); }
    }

    private void open(MethodCall call, MethodChannel.Result result) {
        boolean next = call.method.equals("setNext");
        String value = call.argument("uri");
        long token = number(call, "token", -1).longValue();
        long target = handle;
        if (next && value == null) {
            NativeBindings.open(handle, -1, 0, 0, token, true);
            result.success(null);
            return;
        }
        if (value == null || value.isEmpty()) throw new IllegalArgumentException("Audio URI is required");
        io.execute(() -> {
            try {
                Uri uri = Uri.parse(value);
                int fd;
                long offset;
                long length;
                if (uri.getScheme() == null || "file".equals(uri.getScheme())) {
                    File file = new File(uri.getScheme() == null ? value : uri.getPath());
                    try (ParcelFileDescriptor descriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)) {
                        offset = 0;
                        length = descriptor.getStatSize();
                        fd = descriptor.detachFd();
                    }
                } else if ("content".equals(uri.getScheme())) {
                    try (AssetFileDescriptor descriptor = context.getContentResolver().openAssetFileDescriptor(uri, "r")) {
                        if (descriptor == null) throw new IOException("Audio provider returned no descriptor");
                        offset = descriptor.getStartOffset();
                        length = descriptor.getLength();
                        // The C++ decoder takes ownership. Dup leaves the provider wrapper safe to close.
                        try (ParcelFileDescriptor copy = ParcelFileDescriptor.dup(descriptor.getFileDescriptor())) {
                            fd = copy.detachFd();
                        }
                    }
                } else throw new IOException("Audio must be a local file or content URI");
                main.post(() -> {
                    if (handle != target) {
                        try { ParcelFileDescriptor.adoptFd(fd).close(); } catch (IOException ignored) {}
                        result.error("engine_closed", "Native engine was detached", null);
                        return;
                    }
                    if (!next) requestedToken = token;
                    NativeBindings.open(target, fd, offset, length, token, next);
                    result.success(null);
                });
            } catch (Exception error) { main.post(() -> failure(result, error)); }
        });
    }

    private void transport(String action, long positionMs) {
        if (handle == 0) return;
        // Commands pass through Dart's queue controller so repeat, shuffle,
        // persisted position and the Android session always describe one player.
        if (mediaSink != null) {
            Map<String, Object> event = new HashMap<>();
            event.put("action", action);
            event.put("positionMs", Math.max(0, positionMs));
            mediaSink.success(event);
        } else if ("pause".equals(action) || "stop".equals(action)) {
            pause();
        }
    }

    private void readTags(String value, MethodChannel.Result result) {
        io.execute(() -> {
            Map<String, Object> tags = new HashMap<>();
            try {
                Uri uri = Uri.parse(value);
                try (ParcelFileDescriptor descriptor = uri.getScheme() == null || "file".equals(uri.getScheme())
                        ? ParcelFileDescriptor.open(new File(uri.getScheme() == null ? value : uri.getPath()), ParcelFileDescriptor.MODE_READ_ONLY)
                        : context.getContentResolver().openFileDescriptor(uri, "r")) {
                    if (descriptor != null) {
                        try (ParcelFileDescriptor copy = ParcelFileDescriptor.dup(descriptor.getFileDescriptor())) {
                            Map<String, Object> nativeTags = NativeBindings.readTags(copy.detachFd());
                            if (nativeTags != null) tags.putAll(nativeTags);
                        }
                    }
                }
                // Android's extractor supplies embedded artwork and format
                // information unavailable in the portable TagLib C ABI.
                MediaMetadataRetriever metadata = new MediaMetadataRetriever();
                try {
                    if (uri.getScheme() == null) metadata.setDataSource(value);
                    else metadata.setDataSource(context, uri);
                    putMetadata(tags, metadata, "title", MediaMetadataRetriever.METADATA_KEY_TITLE);
                    putMetadata(tags, metadata, "artist", MediaMetadataRetriever.METADATA_KEY_ARTIST);
                    putMetadata(tags, metadata, "album", MediaMetadataRetriever.METADATA_KEY_ALBUM);
                    String duration = metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
                    if (duration != null) tags.put("durationMs", Long.parseLong(duration));
                    byte[] picture = metadata.getEmbeddedPicture();
                    if (picture != null && picture.length > 0 && picture.length <= 16 * 1024 * 1024) {
                        File directory = new File(context.getFilesDir(), "artwork");
                        if (directory.isDirectory() || directory.mkdirs()) {
                            File art = new File(directory, Integer.toHexString(value.hashCode()) + ".image");
                            try (java.io.FileOutputStream output = new java.io.FileOutputStream(art)) { output.write(picture); }
                            tags.put("artPath", art.getAbsolutePath());
                            tags.put("artUri", Uri.fromFile(art).toString());
                        }
                    }
                } catch (Exception ignored) {
                    // TagLib results remain usable if Android lacks this codec.
                } finally { metadata.release(); }
                main.post(() -> result.success(tags));
            } catch (Exception error) { main.post(() -> failure(result, error)); }
        });
    }

    private static void putMetadata(Map<String, Object> tags, MediaMetadataRetriever metadata, String key, int code) {
        Object existing = tags.get(key);
        if (existing instanceof String && !((String) existing).isEmpty()) return;
        String value = metadata.extractMetadata(code);
        if (value != null && !value.isEmpty()) tags.put(key, value);
    }

    private void createTexture(MethodCall call, MethodChannel.Result result) {
        if (renderer != null || closingTexture) throw new IllegalStateException("Dispose the previous texture first");
        int width = Math.max(64, Math.min(2048, number(call, "width", 720).intValue()));
        int height = Math.max(64, Math.min(2048, number(call, "height", 1280).intValue()));
        visualizerError = "";
        final boolean[] answered = {false};
        renderer = new GeodeTextureRenderer(handle, textures, main, error -> {
            visualizerError = error.toString();
            if (!answered[0]) { answered[0] = true; failure(result, error); closeTexture(() -> {}); }
        });
        long id = renderer.id();
        renderer.start(width, height, () -> {
            if (!answered[0]) { answered[0] = true; result.success(id); }
        });
    }

    private void closeTexture(Runnable complete) {
        if (renderer == null) { complete.run(); return; }
        GeodeTextureRenderer previous = renderer;
        renderer = null;
        closingTexture = true;
        previous.close(() -> { closingTexture = false; complete.run(); });
    }

    private void loadMilkPreset(String name, MethodChannel.Result result) {
        long target = handle;
        io.execute(() -> {
            try {
                File preset = MilkAssets.extract(context, name);
                main.post(() -> {
                    if (target != handle) { result.error("engine_closed", "Native engine was detached", null); return; }
                    NativeBindings.milk(target, preset.getAbsolutePath());
                    result.success(null);
                });
            } catch (Exception error) { main.post(() -> failure(result, error)); }
        });
    }

    private void equalizer(MethodCall call) {
        List<?> bands = call.argument("bands");
        if (bands == null || bands.size() != 10) throw new IllegalArgumentException("Expected ten EQ bands in dB");
        float[] values = new float[16];
        values[0] = Boolean.TRUE.equals(call.argument("enabled")) ? 1 : 0;
        for (int i = 0; i < 10; i++) values[i + 1] = (float) Math.max(-15, Math.min(15, finite(((Number) bands.get(i)).doubleValue())));
        values[11] = number(call, "bassBoost", 0).floatValue();
        values[12] = number(call, "loudnessDb", 0).floatValue();
        values[13] = (float) finite(number(call, "gainDb", 0).doubleValue());
        values[14] = Boolean.TRUE.equals(call.argument("crossfeed")) ? 1 : 0;
        values[15] = Boolean.FALSE.equals(call.argument("limiter")) ? 0 : 1;
        NativeBindings.equalizer(handle, values);
    }

    void play() {
        if (audio.requestAudioFocus(focus) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
            throw new IllegalStateException("Audio focus is unavailable");
        resumeOnFocus = false;
        NativeBindings.command(handle, 0, 0, 0);
    }

    void pause() { NativeBindings.command(handle, 1, 0, 0); abandonFocus(); }
    private void abandonFocus() { resumeOnFocus = false; audio.abandonAudioFocusRequest(focus); }
    private void focusChanged(int change) {
        if (handle == 0) return;
        if (change == AudioManager.AUDIOFOCUS_GAIN) {
            NativeBindings.command(handle, 4, 0, volume);
            if (resumeOnFocus) { resumeOnFocus = false; NativeBindings.command(handle, 0, 0, 0); }
        } else if (change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK) {
            NativeBindings.command(handle, 4, 0, volume * 0.2);
        } else {
            resumeOnFocus = change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT && NativeBindings.snapshot(handle)[1] != 0;
            NativeBindings.command(handle, 1, 0, 0);
        }
    }

    private final BroadcastReceiver noisy = new BroadcastReceiver() {
        @Override public void onReceive(Context ignored, Intent intent) { if (handle != 0) pause(); }
    };

    @Override public void onDetachedFromEngine(FlutterPluginBinding binding) {
        main.removeCallbacks(poll);
        methods.setMethodCallHandler(null);
        playbackEvents.setStreamHandler(null);
        featureEvents.setStreamHandler(null);
        mediaEvents.setStreamHandler(null);
        mediaSink = null;
        GeodePlaybackService.detach(context);
        playbackSink = null;
        featureSink = null;
        context.unregisterReceiver(noisy);
        ((Application) context).unregisterActivityLifecycleCallbacks(this);
        abandonFocus();
        long previous = handle;
        handle = 0;
        closeTexture(() -> {
            io.execute(() -> { if (previous != 0) NativeBindings.destroy(previous); });
            io.shutdown();
        });
    }

    private static Number number(MethodCall call, String key, Number fallback) {
        Object value = call.argument(key);
        return value instanceof Number ? (Number) value : fallback;
    }
    private static String requiredString(MethodCall call, String key) {
        String value = call.argument(key);
        if (value == null || value.isEmpty()) throw new IllegalArgumentException(key + " is required");
        return value;
    }
    private static double finite(double value) {
        if (!Double.isFinite(value)) throw new IllegalArgumentException("Expected a finite number");
        return value;
    }
    private static void failure(MethodChannel.Result result, Throwable error) {
        result.error("geode_native", error.getMessage() == null ? error.toString() : error.getMessage(), null);
    }

    @Override public void onAttachedToActivity(ActivityPluginBinding binding) { activity = binding.getActivity(); }
    @Override public void onDetachedFromActivityForConfigChanges() { activity = null; }
    @Override public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) { activity = binding.getActivity(); }
    @Override public void onDetachedFromActivity() { activity = null; }
    @Override public void onActivityResumed(Activity value) { if (value == activity && renderer != null) renderer.setVisible(true); }
    @Override public void onActivityPaused(Activity value) { if (value == activity && renderer != null) renderer.setVisible(false); }
    @Override public void onActivityCreated(Activity value, Bundle state) {}
    @Override public void onActivityStarted(Activity value) {}
    @Override public void onActivityStopped(Activity value) {}
    @Override public void onActivitySaveInstanceState(Activity value, Bundle state) {}
    @Override public void onActivityDestroyed(Activity value) {}
}
