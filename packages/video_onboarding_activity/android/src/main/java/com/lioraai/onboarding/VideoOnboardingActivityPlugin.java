package com.lioraai.onboarding;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.BitmapFactory;
import android.graphics.drawable.Icon;
import android.os.Build;
import android.provider.Settings;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/** No running service is needed: Android owns the posted notification. */
public final class VideoOnboardingActivityPlugin implements FlutterPlugin,
        MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.NewIntentListener {
    static final String OPEN_IMAGE_TO_VIDEO = "com.lioraai.onboarding.OPEN_IMAGE_TO_VIDEO";
    static final String CHANNEL = "liora_video_onboarding_v2";
    static final String LEGACY_CHANNEL = "liora_video_onboarding_v1";
    private static final int NOTIFICATION_ID = 71003;
    // The main engine and Firebase background engine share this lock and store.
    private static final Object LOCK = new Object();
    private Context context;
    private MethodChannel channel;
    private ActivityPluginBinding activityBinding;
    private boolean listeningForOpens;
    private boolean pendingOpen;

    public VideoOnboardingActivityPlugin() {}

    VideoOnboardingActivityPlugin(Context context) {
        this.context = context;
    }

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "liora/video_onboarding_activity");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        listeningForOpens = false;
        context = null;
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        activityBinding = binding;
        binding.addOnNewIntentListener(this);
        onNewIntent(binding.getActivity().getIntent());
    }

    @Override
    public void onDetachedFromActivity() {
        if (activityBinding != null) activityBinding.removeOnNewIntentListener(this);
        activityBinding = null;
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() { onDetachedFromActivity(); }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public boolean onNewIntent(Intent intent) {
        if (intent == null || !OPEN_IMAGE_TO_VIDEO.equals(intent.getAction())) return false;
        // Consume the action so reattaching an Activity cannot replay the tap.
        intent.setAction(Intent.ACTION_MAIN);
        if (listeningForOpens && channel != null) {
            channel.invokeMethod("openImageToVideo", null);
        } else {
            pendingOpen = true;
        }
        return true;
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (call.method.equals("listenForOpens")) {
            listeningForOpens = true;
            boolean open = pendingOpen;
            pendingOpen = false;
            result.success(open);
            return;
        }
        if (call.method.equals("claimLockScreenSetup")) {
            if (Build.VERSION.SDK_INT < 26) {
                result.success(false);
                return;
            }
            synchronized (LOCK) {
                SharedPreferences prefs = context.getSharedPreferences("liora_video_onboarding", Context.MODE_PRIVATE);
                NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
                boolean eligible = manager.areNotificationsEnabled()
                        && !prefs.getBoolean("lock_screen_setup_offered", false);
                result.success(eligible && prefs.edit().putBoolean("lock_screen_setup_offered", true).commit());
            }
            return;
        }
        if (call.method.equals("openNotificationSettings")) {
            try {
                Intent settings = new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, context.getPackageName())
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                context.startActivity(settings);
                result.success(true);
            } catch (RuntimeException error) {
                result.error("settings_failed", "Could not open notification settings", null);
            }
            return;
        }
        if (!call.method.equals("refresh") && !call.method.equals("recordCompleted")
                && !call.method.equals("completedCount")) {
            result.notImplemented();
            return;
        }
        try {
            synchronized (LOCK) {
                SharedPreferences prefs = context.getSharedPreferences(
                        "liora_video_onboarding", Context.MODE_PRIVATE);
                Set<String> ids = new HashSet<>(prefs.getStringSet("completed_request_ids", new HashSet<>()));
                int count = prefs.getInt("completed_count", ids.size());
                if (call.method.equals("completedCount")) {
                    result.success(count);
                    return;
                }
                if (call.method.equals("recordCompleted") && count < 3) {
                    List<String> incoming = call.argument("requestIds");
                    if (incoming != null) {
                        for (String id : incoming) {
                            if (id != null && !id.trim().isEmpty() && ids.add(id.trim())) {
                                count++;
                                if (count >= 3) break;
                            }
                        }
                    }
                    // Commit before cancelling; completion survives process termination.
                    if (!prefs.edit().putStringSet("completed_request_ids", ids)
                            .putInt("completed_count", count).commit()) {
                        result.error("storage_failed", "Could not save completed video count", null);
                        return;
                    }
                }
                render(count);
            }
            result.success(null);
        } catch (RuntimeException error) {
            result.error("notification_failed", error.getMessage(), null);
        }
    }

    private void render(int count) {
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (count >= 3) {
            manager.cancel(NOTIFICATION_ID);
            return;
        }
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) return;
        if (!manager.areNotificationsEnabled()) return;
        ensureNotificationChannel(manager);

        Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (launch == null) return;
        launch.setAction(OPEN_IMAGE_TO_VIDEO);
        launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent open = PendingIntent.getActivity(context, NOTIFICATION_ID, launch,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        manager.notify(NOTIFICATION_ID, buildNotification(count, open));
    }

    Notification buildNotification(int count, PendingIntent open) {
        String title = context.getString(count == 0
                ? R.string.liora_activity_title : R.string.liora_activity_next_title);
        String description = context.getString(count == 0
                ? R.string.liora_activity_subtitle : R.string.liora_activity_next_subtitle);
        Notification.Builder builder = Build.VERSION.SDK_INT >= 26
                ? new Notification.Builder(context, CHANNEL) : new Notification.Builder(context);
        // System templates handle lock-screen sizing, contrast and manufacturer styling.
        return builder.setSmallIcon(R.drawable.liora_activity_icon)
                .setLargeIcon(BitmapFactory.decodeResource(context.getResources(), R.drawable.liora_activity_logo))
                .setContentTitle(title)
                .setContentText(description)
                .setSubText(context.getString(R.string.liora_activity_count, count))
                .setStyle(new Notification.BigTextStyle().bigText(description))
                .setProgress(3, count, false)
                .setColor(Color.rgb(164, 92, 244))
                .setContentIntent(open)
                .addAction(new Notification.Action.Builder(
                        Icon.createWithResource(context, R.drawable.liora_activity_icon),
                        context.getString(R.string.liora_activity_open), open).build())
                .setCategory(Notification.CATEGORY_STATUS)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setOngoing(true)
                .setAutoCancel(false)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .build();
    }

    void ensureNotificationChannel(NotificationManager manager) {
        if (Build.VERSION.SDK_INT < 26) return;
        if (manager.getNotificationChannel(CHANNEL) == null) {
            NotificationChannel legacy = manager.getNotificationChannel(LEGACY_CHANNEL);
            // Upgrade our old LOW default, while preserving an explicitly blocked channel.
            int importance = legacy != null && legacy.getImportance() == NotificationManager.IMPORTANCE_NONE
                    ? NotificationManager.IMPORTANCE_NONE : NotificationManager.IMPORTANCE_DEFAULT;
            NotificationChannel notificationChannel = new NotificationChannel(
                    CHANNEL, context.getString(R.string.liora_activity_channel), importance);
            notificationChannel.setDescription(context.getString(R.string.liora_activity_channel_description));
            notificationChannel.setShowBadge(false);
            notificationChannel.setLockscreenVisibility(legacy != null
                    ? legacy.getLockscreenVisibility() : Notification.VISIBILITY_PUBLIC);
            manager.createNotificationChannel(notificationChannel);
        }
        // Do not recreate the new channel: subsequent user settings must remain effective.
        manager.deleteNotificationChannel(LEGACY_CHANNEL);
    }

}
