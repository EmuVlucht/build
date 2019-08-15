import 'package:flutter/material.dart';
import 'app.dart';
import 'models/settings_model.dart';
import 'services/foreground_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ForegroundSvc.init();  // inisialisasi foreground task
  final settings = await AppSettings.load();
  runApp(App(initialSettings: settings));
}
