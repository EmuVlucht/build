import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundSvc {
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId:          'netshelfy_channel',
        channelName:        'NetShelfy+',
        channelDescription: 'Server sedang berjalan di background',
        channelImportance:  NotificationChannelImportance.LOW,
        priority:           NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction:    ForegroundTaskEventAction.nothing(),
        autoRunOnBoot:  false,   // jangan auto start saat reboot
        allowWakeLock:  true,
        allowWifiLock:  true,
      ),
    );
  }

  static Future<void> requestPermission() async {
    if (Platform.isAndroid) {
      final result = await FlutterForegroundTask.checkNotificationPermission();
      if (result != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    }
  }

  static Future<void> start({
    required String directory,
    required int port,
  }) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'NetShelfy+ Aktif',
        notificationText:  '$directory · port $port',
      );
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId:         1001,
      notificationTitle: 'NetShelfy+ Aktif',
      notificationText:  '$directory · port $port',
      notificationButtons: [
        const NotificationButton(id: 'btn_stop', text: 'Stop'),
      ],
      callback: _foregroundCallback,
    );
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }

  static Future<bool> get isRunning => FlutterForegroundTask.isRunningService;
}

@pragma('vm:entry-point')
void _foregroundCallback() {
  FlutterForegroundTask.setTaskHandler(_NetShelfyTaskHandler());
}

class _NetShelfyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'btn_stop') {
      FlutterForegroundTask.sendDataToMain('stop');
    }
  }
}
