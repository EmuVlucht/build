import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/settings_model.dart';
import '../services/server_service.dart';
import '../services/update_service.dart';
import '../services/foreground_service.dart';
import 'file_browser_screen.dart';
import 'settings_screen.dart';
import 'update_dialog.dart';

class HomeScreen extends StatefulWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  const HomeScreen({super.key, required this.settings, required this.onSettingsChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final _service = ServerService();
  String _selectedFolder = '/storage/emulated/0';

  // 3 tipe IP
  final String _loopbackIp = '127.0.0.1';
  String? _privateIp;
  String? _publicIp;
  bool _fetchingIp  = false;
  bool _ipExpanded  = false;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  AppSettings get _settings => widget.settings;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 1.0, end: 1.06).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _requestPermissions();
    Future.delayed(const Duration(seconds: 2), _checkForUpdate);
    // Listen data dari foreground service (tombol Stop di notifikasi)
    FlutterForegroundTask.addTaskDataCallback(_onForegroundData);
  }

  void _onForegroundData(Object data) {
    if (data == 'stop' || (data is Map && data['action'] == 'stop')) {
      _doStop();
    }
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onForegroundData);
    _pulseCtrl.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
      await ForegroundSvc.requestPermission();
    }
  }

  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    final info = await UpdateService.checkForUpdate();
    if (!mounted || info == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(info: info),
    );
  }

  // ── IP fetch ──────────────────────────────────────────────────
  Future<String?> _getPrivateIp() async {
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLinkLocal: false);
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('wlan') || name.contains('wifi') || name.contains('wl')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) return addr.address;
          }
        }
      }
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _getPublicIp() async {
    final services = [
      'https://api.ipify.org',
      'https://icanhazip.com',
      'https://ipecho.net/plain',
    ];
    for (final url in services) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 8);
        final req  = await client.getUrl(Uri.parse(url));
        final resp = await req.close();
        final body = await resp.transform(const SystemEncoding().decoder).join();
        client.close();
        final ip = body.trim();
        if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(ip)) {
          return ip;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _fetchAllIps() async {
    setState(() => _fetchingIp = true);
    final results = await Future.wait([_getPrivateIp(), _getPublicIp()]);
    if (mounted) {
      setState(() {
        _privateIp  = results[0];
        _publicIp   = results[1];
        _fetchingIp = false;
      });
    }
  }

  // ── Server control ────────────────────────────────────────────
  Future<void> _onMainButton() async {
    final state = _service.state;
    if (state == ServerState.idle) {
      _showStarting();
      final err = await _service.start(_selectedFolder, _settings);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (err != null) {
        _showError(err);
      } else {
        _fetchAllIps();
        if (_settings.keepAlive) {
          await ForegroundSvc.start(
            directory: _selectedFolder,
            port: _settings.port,
          );
        }
      }
    } else {
      _showControlSheet(state);
    }
  }

  void _doStop() {
    _service.stop();
    ForegroundSvc.stop();
    if (mounted) {
      setState(() {
        _privateIp  = null;
        _publicIp   = null;
        _fetchingIp = false;
        _ipExpanded = false;
      });
    }
  }

  void _showStarting() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('Memulai server...\n(pertama kali mungkin lebih lama)')),
        ]),
      ),
    );
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Gagal Memulai'),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _showControlSheet(ServerState state) {
    final isActive = state == ServerState.active;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 8),
        ListTile(
          leading: CircleAvatar(
            radius: 8,
            backgroundColor: isActive ? Colors.green : Colors.orange,
          ),
          title: Text(isActive ? 'Server Aktif' : 'Server Dijeda',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.green : Colors.orange)),
        ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(
              isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
              size: 28, color: isActive ? Colors.orange : Colors.green),
          title: Text(isActive ? 'Pause' : 'Resume',
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.orange : Colors.green)),
          subtitle: Text(
              isActive ? 'Jeda sementara — koneksi baru ditahan' : 'Lanjutkan server',
              style: const TextStyle(fontSize: 12)),
          onTap: () {
            Navigator.pop(ctx);
            if (isActive) _service.pause(); else _service.resume();
          },
        ),
        ListTile(
          leading: const Icon(Icons.stop_circle_outlined, size: 28, color: Colors.red),
          title: const Text('Stop',
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.red)),
          subtitle: const Text('Hentikan server sepenuhnya',
              style: TextStyle(fontSize: 12)),
          onTap: () {
            Navigator.pop(ctx);
            _doStop();
          },
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Future<void> _pickFolder() async {
    final result = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const FileBrowserScreen()));
    if (result != null && mounted) setState(() => _selectedFolder = result);
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen(
          settings: _settings,
          onChanged: widget.onSettingsChanged,
          selectedFolder: _selectedFolder)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: StreamBuilder<ServerState>(
        stream: _service.stateStream,
        initialData: _service.state,
        builder: (context, snap) {
          final state     = snap.data ?? ServerState.idle;
          final isRunning = state != ServerState.idle;
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              title: const Text('NetShelfy+',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              centerTitle: true,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Pengaturan',
                  onPressed: isRunning ? null : _openSettings,
                ),
              ],
            ),
            body: Column(children: [
              // ── Tombol power ──────────────────────────────────
              Expanded(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width:  state == ServerState.active ? 200 : 180,
                      height: state == ServerState.active ? 200 : 180,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _ringColor(state).withOpacity(0.12)),
                      child: Center(
                        child: ScaleTransition(
                          scale: state == ServerState.active
                              ? _pulseAnim
                              : const AlwaysStoppedAnimation(1.0),
                          child: GestureDetector(
                            onTap: _onMainButton,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                              width: 150, height: 150,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _buttonColor(state),
                                  boxShadow: [BoxShadow(
                                      color: _buttonColor(state).withOpacity(0.45),
                                      blurRadius: 24, spreadRadius: 4)]),
                              child: Icon(_buttonIcon(state),
                                  size: 60, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(_stateLabel(state),
                          key: ValueKey(state),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _buttonColor(state))),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        state == ServerState.idle
                            ? 'Tap untuk memulai server'
                            : 'Tap untuk kontrol server',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500)),
                  ]),
                ),
              ),

              // ── IP pill + dropdown ────────────────────────────
              if (isRunning) _buildIpSection(context),

              // ── Folder card ───────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(14),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.3)),
                child: ListTile(
                  leading: const Icon(Icons.folder_rounded,
                      color: Colors.amber, size: 28),
                  title: Text(_selectedFolder,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  subtitle: const Text('Folder yang akan di-serve',
                      style: TextStyle(fontSize: 11)),
                  trailing: TextButton(
                      onPressed: isRunning ? null : _pickFolder,
                      child: const Text('Ganti')),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  // ── IP pill + dropdown ────────────────────────────────────────
  Widget _buildIpSection(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final port = _settings.port;
    final pillUrl = _privateIp != null
        ? 'http://$_privateIp:$port'
        : 'http://[IP-HP]:$port';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Pill
        GestureDetector(
          onTap: () => setState(() => _ipExpanded = !_ipExpanded),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.4),
              border: Border.all(color: cs.outline.withOpacity(0.25)),
              borderRadius: _ipExpanded
                  ? const BorderRadius.vertical(top: Radius.circular(12))
                  : BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Akses dari browser:',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const Spacer(),
                AnimatedRotation(
                  turns: _ipExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: Colors.grey.shade500),
                ),
              ]),
              const SizedBox(height: 2),
              Text(pillUrl,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: cs.primary)),
            ]),
          ),
        ),

        // Dropdown
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _ipExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.4),
              border: Border(
                left:   BorderSide(color: cs.outline.withOpacity(0.25)),
                right:  BorderSide(color: cs.outline.withOpacity(0.25)),
                bottom: BorderSide(color: cs.outline.withOpacity(0.25)),
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Column(children: [
              Divider(height: 1, color: cs.outline.withOpacity(0.15)),
              _ipRow(context: context, label: 'Loopback',
                  sublabel: 'Browser di HP ini',
                  icon: Icons.phone_android_rounded, color: Colors.blueGrey,
                  ip: _loopbackIp, port: port, loading: false),
              Divider(height: 1, indent: 14, color: cs.outline.withOpacity(0.1)),
              _ipRow(context: context, label: 'Local (WiFi)',
                  sublabel: 'Perangkat di jaringan sama',
                  icon: Icons.wifi_rounded, color: Colors.green.shade600,
                  ip: _privateIp, port: port,
                  loading: _fetchingIp && _privateIp == null),
              Divider(height: 1, indent: 14, color: cs.outline.withOpacity(0.1)),
              _ipRow(context: context, label: 'Public',
                  sublabel: 'Dari internet (perlu port forward)',
                  icon: Icons.public_rounded, color: Colors.orange.shade700,
                  ip: _publicIp, port: port,
                  loading: _fetchingIp && _publicIp == null),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _ipRow({
    required BuildContext context,
    required String label,
    required String sublabel,
    required IconData icon,
    required Color color,
    required String? ip,
    required int port,
    required bool loading,
  }) {
    final url = ip != null ? 'http://$ip:$port' : null;
    final cs  = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: url == null ? null : () {
        Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Disalin: $url'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            Text(sublabel, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ])),
          if (loading)
            SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
          else if (url != null)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(url, style: TextStyle(
                  fontFamily: 'monospace', fontSize: 12,
                  fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 6),
              Icon(Icons.copy_rounded, size: 13, color: Colors.grey.shade400),
            ])
          else
            Text('Tidak tersedia',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ]),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────
  Color _ringColor(ServerState s) {
    switch (s) {
      case ServerState.idle:   return Colors.blueGrey;
      case ServerState.active: return Colors.green;
      case ServerState.paused: return Colors.orange;
    }
  }

  Color _buttonColor(ServerState s) {
    switch (s) {
      case ServerState.idle:   return Colors.blueGrey.shade600;
      case ServerState.active: return Colors.green.shade600;
      case ServerState.paused: return Colors.orange.shade700;
    }
  }

  IconData _buttonIcon(ServerState s) {
    switch (s) {
      case ServerState.idle:   return Icons.power_settings_new_rounded;
      case ServerState.active: return Icons.cloud_upload_rounded;
      case ServerState.paused: return Icons.pause_rounded;
    }
  }

  String _stateLabel(ServerState s) {
    switch (s) {
      case ServerState.idle:   return 'Idle';
      case ServerState.active: return 'Active';
      case ServerState.paused: return 'Paused';
    }
  }
}
