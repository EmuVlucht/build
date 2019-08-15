import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final int port;
  final ThemeMode themeMode;
  final String basicAuth;
  final String basicAuthUpload;

  const AppSettings({
    this.port = 8000,
    this.themeMode = ThemeMode.system,
    this.basicAuth = '',
    this.basicAuthUpload = '',
  });

  String get themeArg {
    switch (themeMode) {
      case ThemeMode.light:  return 'light';
      case ThemeMode.dark:   return 'dark';
      case ThemeMode.system: return 'auto';
    }
  }

  String buildCommand(String directory) {
    final parts = <String>[
      'python -m uploadserver',
      '--bind 0.0.0.0',
      '--directory $directory',
      '--theme $themeArg',
    ];
    if (basicAuth.isNotEmpty) parts.add('--basic-auth $basicAuth');
    if (basicAuthUpload.isNotEmpty) parts.add('--basic-auth-upload $basicAuthUpload');
    parts.add('$port');
    return parts.join(' ');
  }

  static const _kPort   = 'port';
  static const _kTheme  = 'theme';
  static const _kAuth   = 'basic_auth';
  static const _kAuthUp = 'basic_auth_upload';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      port:            prefs.getInt(_kPort) ?? 8000,
      themeMode:       _themeFromStr(prefs.getString(_kTheme) ?? 'system'),
      basicAuth:       prefs.getString(_kAuth)   ?? '',
      basicAuthUpload: prefs.getString(_kAuthUp) ?? '',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPort, port);
    await prefs.setString(_kTheme, _themeToStr(themeMode));
    await prefs.setString(_kAuth, basicAuth);
    await prefs.setString(_kAuthUp, basicAuthUpload);
  }

  AppSettings copyWith({
    int? port,
    ThemeMode? themeMode,
    String? basicAuth,
    String? basicAuthUpload,
  }) {
    return AppSettings(
      port:            port            ?? this.port,
      themeMode:       themeMode       ?? this.themeMode,
      basicAuth:       basicAuth       ?? this.basicAuth,
      basicAuthUpload: basicAuthUpload ?? this.basicAuthUpload,
    );
  }

  static ThemeMode _themeFromStr(String s) {
    switch (s) {
      case 'light': return ThemeMode.light;
      case 'dark':  return ThemeMode.dark;
      default:      return ThemeMode.system;
    }
  }

  static String _themeToStr(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:  return 'light';
      case ThemeMode.dark:   return 'dark';
      case ThemeMode.system: return 'system';
    }
  }
}
