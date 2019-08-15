import 'dart:async';
import 'package:flutter/services.dart';
import '../models/settings_model.dart';

enum ServerState { idle, active, paused }

class ServerService {
  static const _channel = MethodChannel('com.uploadserver.app/server');

  ServerState _state = ServerState.idle;
  final _stateCtrl = StreamController<ServerState>.broadcast();

  Stream<ServerState> get stateStream => _stateCtrl.stream;
  ServerState get state => _state;

  void _setState(ServerState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  Future<String?> start(String directory, AppSettings settings) async {
    try {
      final result = await _channel.invokeMethod<String>('start', {
        'directory':   directory,
        'port':        settings.port,
        'theme':       settings.themeArg,
        'basicAuth':   settings.basicAuth,
        'basicAuthUp': settings.basicAuthUpload,
      });
      if (result == 'ok' || result == 'already_running') {
        _setState(ServerState.active);
        return null;
      }
      return result ?? 'Unknown error';
    } on PlatformException catch (e) {
      return e.message ?? 'Platform error';
    }
  }

  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
      _setState(ServerState.paused);
    } on PlatformException catch (_) {}
  }

  Future<void> resume() async {
    try {
      await _channel.invokeMethod('resume');
      _setState(ServerState.active);
    } on PlatformException catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } on PlatformException catch (_) {}
    _setState(ServerState.idle);
  }

  void dispose() {
    stop();
    _stateCtrl.close();
  }
}
