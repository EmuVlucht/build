import 'package:flutter/material.dart';
import 'models/settings_model.dart';
import 'screens/home_screen.dart';

class App extends StatefulWidget {
  final AppSettings initialSettings;
  const App({super.key, required this.initialSettings});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  void updateSettings(AppSettings s) {
    setState(() => _settings = s);
    s.save();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UploadServer',
      debugShowCheckedModeBanner: false,
      themeMode: _settings.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(
        settings: _settings,
        onSettingsChanged: updateSettings,
      ),
    );
  }
}
