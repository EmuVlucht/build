import 'package:flutter/material.dart';
import 'app.dart';
import 'models/settings_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(App(initialSettings: settings));
}
