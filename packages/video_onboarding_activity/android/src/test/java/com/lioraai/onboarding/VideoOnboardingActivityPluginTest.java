package com.lioraai.onboarding;

import static org.junit.Assert.*;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.view.View;
import android.widget.TextView;

import java.util.Arrays;
import java.util.Collections;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 28)
public class VideoOnboardingActivityPluginTest {
    private Context context;
    private VideoOnboardingActivityPlugin plugin;

    @Before public void setup() {
        context = RuntimeEnvironment.getApplication();
        context.getSharedPreferences("liora_video_onboarding", Context.MODE_PRIVATE).edit().clear().commit();
        plugin = new VideoOnboardingActivityPlugin(context);
    }

    @Test public void countsUniqueVideosAndPersistsAcrossEngineRestarts() {
        complete("one", "one", "", "  ");
        assertEquals(1, count());
        plugin = new VideoOnboardingActivityPlugin(context);
        assertEquals(1, count());
        complete("one", "two");
        assertEquals(2, count());
        complete("three", "four");
        assertEquals(3, count());
        complete("five");
        assertEquals(3, count());
    }

    @Test public void refreshNeverResetsProgress() {
        complete("one", "two");
        call("refresh", null);
        assertEquals(2, count());
    }

    @Test public void coldNotificationTapIsDeliveredOnceWhenDartStartsListening() {
        Intent tap = new Intent(VideoOnboardingActivityPlugin.OPEN_IMAGE_TO_VIDEO);
        assertTrue(plugin.onNewIntent(tap));
        assertEquals(Intent.ACTION_MAIN, tap.getAction());
        assertEquals(true, call("listenForOpens", null));
        assertEquals(false, call("listenForOpens", null));
        assertFalse(plugin.onNewIntent(tap));
    }

    @Test public void normalLauncherDoesNotRequestImageToVideo() {
        assertFalse(plugin.onNewIntent(new Intent(Intent.ACTION_MAIN)));
        assertEquals(false, call("listenForOpens", null));
    }

    @Test public void thirdVideoCancelsNotificationAndFutureRefreshKeepsItHidden() {
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        manager.notify(71003, new Notification());
        assertEquals(1, manager.getActiveNotifications().length);
        complete("one", "two", "three");
        assertEquals(0, manager.getActiveNotifications().length);
        call("refresh", null);
        assertEquals(0, manager.getActiveNotifications().length);
    }

    @Test public void bothLayoutsInflateWithProgressAndOpenAction() {
        PendingIntent open = PendingIntent.getActivity(context, 0, new Intent("test.open"), PendingIntent.FLAG_IMMUTABLE);
        for (int layout : new int[]{R.layout.liora_video_onboarding, R.layout.liora_video_onboarding_compact}) {
            View root = plugin.createView(layout, 2, open).apply(context, null);
            assertEquals(layout == R.layout.liora_video_onboarding_compact
                            ? "Your first videos: 2/3" : "Create your first videos: 2/3",
                    ((TextView) root.findViewById(R.id.liora_activity_title)).getText().toString());
            assertEquals("2 of 3 videos created", root.findViewById(R.id.liora_activity_progress).getContentDescription());
            assertNotNull(root.findViewById(R.id.liora_activity_open));
            assertNotNull(root.findViewById(R.id.liora_segment_three));
        }
    }

    private void complete(String... ids) {
        call("recordCompleted", Collections.singletonMap("requestIds", Arrays.asList(ids)));
    }

    private int count() {
        return (Integer) call("completedCount", null);
    }

    private Object call(String method, Object arguments) {
        final Object[] value = {null};
        plugin.onMethodCall(new MethodCall(method, arguments), new MethodChannel.Result() {
            @Override public void success(Object result) { value[0] = result; }
            @Override public void error(String code, String message, Object details) { fail(code + ": " + message); }
            @Override public void notImplemented() { fail("Method not implemented"); }
        });
        return value[0];
    }
}
