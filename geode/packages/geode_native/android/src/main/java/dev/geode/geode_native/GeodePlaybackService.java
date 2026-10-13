package dev.geode.geode_native;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.media.MediaMetadata;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.os.SystemClock;

import java.util.Map;
import java.util.Objects;

/**
 * Android's background and system-control host for the existing C++ player.
 *
 * <p>The Flutter engine owns the native session and queue. This service never
 * creates a second player: transport commands go back to that engine. Its
 * lifetime covers backgrounding and screen lock, and ends when the owning
 * Flutter engine detaches. A killed process is deliberately not restarted with
 * an empty queue or a stale native handle.</p>
 */
public final class GeodePlaybackService extends Service {
    public interface TransportDelegate {
        /** Called on Android's main thread. Seek positions are milliseconds. */
        void onCommand(String action, long positionMs);
    }

    private static final String CHANNEL = "geode_playback";
    private static final String ACTION_PREFIX = "dev.geode.geode_native.playback.";
    private static final int NOTIFICATION_ID = 7301;
    private static final long WAKE_TIMEOUT_MS = 10 * 60 * 1000L;
    private static final Handler MAIN = new Handler(Looper.getMainLooper());

    // All access occurs on the main thread, including platform-channel calls.
    private static TransportDelegate delegate;
    private static GeodePlaybackService instance;
    private static PlaybackInfo current = PlaybackInfo.empty();

    private MediaSession mediaSession;
    private NotificationManager notifications;
    private PowerManager.WakeLock wakeLock;
    private boolean foreground;
    private PlaybackInfo displayed;
    private final Runnable renewWakeLock = new Runnable() {
        @Override public void run() {
            if (current.playing && wakeLock != null) {
                wakeLock.acquire(WAKE_TIMEOUT_MS);
                MAIN.postDelayed(this, WAKE_TIMEOUT_MS / 2);
            }
        }
    };

    /** Attach only the owner of the live native player, never an Activity. */
    public static void attach(Context context, TransportDelegate transport) {
        delegate = Objects.requireNonNull(transport);
    }

    /** Must run before destroying the native player on engine detach. */
    public static void detach(Context context) {
        delegate = null;
        GeodeNowPlayingWidget.clear(context);
        current = PlaybackInfo.empty();
        if (instance != null) instance.finishService();
        context.getApplicationContext().stopService(
                new Intent(context.getApplicationContext(), GeodePlaybackService.class));
    }

    /**
     * Publishes real player state. Merely selecting a paused track does not
     * start a foreground service; playback starts it while the app is visible.
     */
    public static void update(Context context, Map<?, ?> state) {
        current = PlaybackInfo.from(state);
        GeodeNowPlayingWidget.update(context, state);
        if (delegate == null) return;
        if (!current.hasMedia) {
            if (instance != null) instance.finishService();
            return;
        }
        if (instance != null) {
            instance.publishState();
        } else if (current.playing) {
            Context application = context.getApplicationContext();
            application.startForegroundService(new Intent(application, GeodePlaybackService.class));
        }
    }

    @Override public void onCreate() {
        super.onCreate();
        instance = this;
        notifications = getSystemService(NotificationManager.class);
        NotificationChannel channel = new NotificationChannel(
                CHANNEL, "Music playback", NotificationManager.IMPORTANCE_LOW);
        channel.setDescription("Playback controls for your current Geode queue");
        channel.setShowBadge(false);
        channel.setSound(null, null);
        notifications.createNotificationChannel(channel);

        PowerManager power = getSystemService(PowerManager.class);
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Geode:MusicPlayback");
        wakeLock.setReferenceCounted(false);
        mediaSession = new MediaSession(this, "Geode");
        mediaSession.setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS
                | MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS);
        mediaSession.setCallback(new MediaSession.Callback() {
            @Override public void onPlay() { dispatch("play", -1); }
            @Override public void onPause() { dispatch("pause", -1); }
            @Override public void onStop() { dispatch("stop", -1); }
            @Override public void onSkipToNext() { dispatch("next", -1); }
            @Override public void onSkipToPrevious() { dispatch("previous", -1); }
            @Override public void onSeekTo(long position) {
                dispatch("seek", Math.max(0, current.durationMs > 0
                        ? Math.min(position, current.durationMs) : position));
            }
        }, MAIN);
        PendingIntent launch = launchIntent();
        if (launch != null) mediaSession.setSessionActivity(launch);
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        // A foreground-service launch must publish promptly even if a pause or
        // engine detach arrived between startForegroundService and this call.
        enterForeground();
        if (delegate == null || !current.hasMedia) {
            finishService();
            return START_NOT_STICKY;
        }
        String action = intent == null ? null : intent.getAction();
        if (action != null && action.startsWith(ACTION_PREFIX)) {
            dispatch(action.substring(ACTION_PREFIX.length()), -1);
        }
        publishState();
        return START_NOT_STICKY;
    }

    @Override public IBinder onBind(Intent intent) { return null; }

    @Override public void onTaskRemoved(Intent rootIntent) {
        // An ordinary FlutterActivity may destroy its engine when dismissed.
        // It is not safe to retain that engine's JNI handle or queue afterwards.
        dispatch("stop", -1);
        super.onTaskRemoved(rootIntent);
    }

    @Override public void onDestroy() {
        if (instance == this) instance = null;
        releaseWakeLock();
        if (mediaSession != null) {
            mediaSession.setActive(false);
            mediaSession.release();
            mediaSession = null;
        }
        notifications.cancel(NOTIFICATION_ID);
        if (current.playing && delegate != null) {
            // Unexpected service removal must not leave unprotected playback.
            delegate.onCommand("pause", -1);
        }
        super.onDestroy();
    }

    private void dispatch(String action, long positionMs) {
        TransportDelegate target = delegate;
        if (target == null) {
            finishService();
            return;
        }
        if ("play".equals(action)) {
            // Android 15 requires top-app or foreground-service status before
            // the player requests audio focus when resuming from the lockscreen.
            enterForeground();
        }
        target.onCommand(action, positionMs);
        if ("stop".equals(action)) {
            current = PlaybackInfo.empty();
            finishService();
        }
    }

    private void publishState() {
        if (mediaSession == null) return;
        PlaybackInfo state = current;
        if (!state.hasMedia) {
            finishService();
            return;
        }
        if (displayed == null || !state.sameMetadata(displayed)) {
            MediaMetadata metadata = new MediaMetadata.Builder()
                    .putString(MediaMetadata.METADATA_KEY_MEDIA_ID, state.mediaId)
                    .putString(MediaMetadata.METADATA_KEY_TITLE, state.title)
                    .putString(MediaMetadata.METADATA_KEY_ARTIST, state.artist)
                    .putString(MediaMetadata.METADATA_KEY_ALBUM, state.album)
                    .putLong(MediaMetadata.METADATA_KEY_DURATION, state.durationMs)
                    .build();
            mediaSession.setMetadata(metadata);
        }
        long actions = PlaybackState.ACTION_PLAY | PlaybackState.ACTION_PAUSE
                | PlaybackState.ACTION_PLAY_PAUSE | PlaybackState.ACTION_STOP
                | PlaybackState.ACTION_SEEK_TO | PlaybackState.ACTION_SKIP_TO_PREVIOUS;
        if (state.queueSize > 1) actions |= PlaybackState.ACTION_SKIP_TO_NEXT;
        mediaSession.setPlaybackState(new PlaybackState.Builder()
                .setActions(actions)
                .setState(state.playing ? PlaybackState.STATE_PLAYING : PlaybackState.STATE_PAUSED,
                        state.positionMs, state.playing ? 1f : 0f, SystemClock.elapsedRealtime())
                .setActiveQueueItemId(state.queueIndex)
                .build());
        mediaSession.setActive(true);

        boolean notificationChanged = displayed == null || !state.sameMetadata(displayed)
                || state.playing != displayed.playing || state.queueSize != displayed.queueSize;
        if (state.playing) {
            if (!foreground) enterForeground();
            if (!wakeLock.isHeld()) {
                MAIN.removeCallbacks(renewWakeLock);
                renewWakeLock.run();
            }
        } else {
            releaseWakeLock();
            if (foreground) {
                stopForeground(STOP_FOREGROUND_DETACH);
                foreground = false;
            }
        }
        if (notificationChanged) notifications.notify(NOTIFICATION_ID, notification());
        displayed = state;
    }

    private void enterForeground() {
        if (foreground) return;
        Notification notification = notification();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK);
        } else {
            startForeground(NOTIFICATION_ID, notification);
        }
        foreground = true;
    }

    private Notification notification() {
        PlaybackInfo state = current;
        Notification.Builder builder = new Notification.Builder(this, CHANNEL)
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setContentTitle(state.title.isEmpty() ? "Geode" : state.title)
                .setContentText(state.artist)
                .setSubText(state.album.isEmpty() ? "Geode" : state.album)
                .setCategory(Notification.CATEGORY_TRANSPORT)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setShowWhen(false)
                .setOnlyAlertOnce(true)
                .setOngoing(state.playing)
                .setDeleteIntent(actionIntent("stop"))
                .addAction(new Notification.Action.Builder(
                        android.R.drawable.ic_media_previous, "Previous", actionIntent("previous")).build())
                .addAction(new Notification.Action.Builder(
                        state.playing ? android.R.drawable.ic_media_pause : android.R.drawable.ic_media_play,
                        state.playing ? "Pause" : "Play",
                        actionIntent(state.playing ? "pause" : "play")).build());
        if (state.queueSize > 1) {
            builder.addAction(new Notification.Action.Builder(
                    android.R.drawable.ic_media_next, "Next", actionIntent("next")).build());
        }
        builder.addAction(new Notification.Action.Builder(
                android.R.drawable.ic_menu_close_clear_cancel, "Stop", actionIntent("stop")).build());
        Notification.MediaStyle style = new Notification.MediaStyle()
                .setMediaSession(mediaSession.getSessionToken());
        style.setShowActionsInCompactView(state.queueSize > 1 ? new int[]{0, 1, 2} : new int[]{0, 1});
        builder.setStyle(style);
        PendingIntent launch = launchIntent();
        if (launch != null) builder.setContentIntent(launch);
        return builder.build();
    }

    private PendingIntent actionIntent(String command) {
        Intent intent = new Intent(this, GeodePlaybackService.class).setAction(ACTION_PREFIX + command);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE;
        return "play".equals(command)
                ? PendingIntent.getForegroundService(this, command.hashCode(), intent, flags)
                : PendingIntent.getService(this, command.hashCode(), intent, flags);
    }

    private PendingIntent launchIntent() {
        Intent intent = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (intent == null) return null;
        intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        return PendingIntent.getActivity(this, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private void releaseWakeLock() {
        MAIN.removeCallbacks(renewWakeLock);
        if (wakeLock != null && wakeLock.isHeld()) wakeLock.release();
    }

    private void finishService() {
        releaseWakeLock();
        if (mediaSession != null) mediaSession.setActive(false);
        stopForeground(STOP_FOREGROUND_REMOVE);
        foreground = false;
        if (notifications != null) notifications.cancel(NOTIFICATION_ID);
        stopSelf();
    }

    /** Immutable, bounded values from the Flutter channel. */
    private static final class PlaybackInfo {
        final String mediaId, title, artist, album;
        final long durationMs, positionMs, queueIndex, queueSize;
        final boolean hasMedia, playing;

        PlaybackInfo(String mediaId, String title, String artist, String album,
                     long durationMs, long positionMs, long queueIndex, long queueSize,
                     boolean hasMedia, boolean playing) {
            this.mediaId = mediaId;
            this.title = title;
            this.artist = artist;
            this.album = album;
            this.durationMs = durationMs;
            this.positionMs = durationMs > 0 ? Math.min(positionMs, durationMs) : positionMs;
            this.queueIndex = queueIndex;
            this.queueSize = queueSize;
            this.hasMedia = hasMedia;
            this.playing = hasMedia && playing;
        }

        static PlaybackInfo empty() {
            return new PlaybackInfo("", "", "", "", 0, 0, -1, 0, false, false);
        }

        static PlaybackInfo from(Map<?, ?> values) {
            if (values == null) return empty();
            return new PlaybackInfo(string(values, "mediaId"), string(values, "title"),
                    string(values, "artist"), string(values, "album"),
                    number(values, "durationMs", 0), number(values, "positionMs", 0),
                    number(values, "queueIndex", 0), number(values, "queueSize", 1),
                    !Boolean.FALSE.equals(values.get("hasMedia")),
                    Boolean.TRUE.equals(values.get("playing")));
        }

        boolean sameMetadata(PlaybackInfo other) {
            return mediaId.equals(other.mediaId) && title.equals(other.title)
                    && artist.equals(other.artist) && album.equals(other.album)
                    && durationMs == other.durationMs;
        }

        private static String string(Map<?, ?> values, String key) {
            Object value = values.get(key);
            return value instanceof String ? (String) value : "";
        }

        private static long number(Map<?, ?> values, String key, long fallback) {
            Object value = values.get(key);
            return value instanceof Number ? Math.max(0, ((Number) value).longValue()) : fallback;
        }
    }
}
