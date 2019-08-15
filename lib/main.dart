import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'app.dart';
import 'models/settings_model.dart';
import 'services/foreground_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Wajib di v8+ agar komunikasi isolate ↔ main works
  FlutterForegroundTask.initCommunicationPort();
  ForegroundSvc.init();
  final settings = await AppSettings.load();
  runApp(App(initialSettings: settings));
}
