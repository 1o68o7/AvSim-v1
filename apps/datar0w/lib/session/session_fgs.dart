import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Isolate FGS : garde le process vivant (GPS/IMU LiveHub) écran verrouillé.
@pragma('vm:entry-point')
void datar0wSessionStartCallback() {
  FlutterForegroundTask.setTaskHandler(_SessionTaskHandler());
}

class _SessionTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

Future<void> initSessionForegroundTask() async {
  try {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'datar0w_session',
        channelName: 'Séance DataR0w',
        channelDescription: 'Logger GPS et IMU pendant la séance',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
        stopWithTask: false,
      ),
    );
  } catch (_) {}
}

Future<void> startSessionForeground() async {
  try {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      return;
    }
    await FlutterForegroundTask.startService(
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'DataR0w — séance',
      notificationText: 'GPS + IMU · écran verrouillé OK',
      callback: datar0wSessionStartCallback,
    );
  } catch (_) {}
}

Future<void> stopSessionForeground() async {
  try {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  } catch (_) {}
}
