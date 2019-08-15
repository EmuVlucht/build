import 'dart:io';
import 'package:flutter/material.dart';

class _StorageTab {
  final String label;
  final IconData icon;
  final String root;
  const _StorageTab({required this.label, required this.icon, required this.root});
}

/// Deteksi semua storage eksternal (SD card + USB OTG) via /proc/mounts
/// Lebih reliable daripada scan /storage/ karena tidak butuh permission khusus
List<_StorageTab> _findExternalTabs() {
  final result = <_StorageTab>[];
  final seen   = <String>{};

  // Method 1: Parse /proc/mounts — paling reliable di semua Android
  try {
    final mounts = File('/proc/mounts').readAsStringSync();
    for (final line in mounts.split('\n')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 3) continue;
      final mountPoint = parts[1];
      final fsType     = parts[2];

      // Hanya ambil storage eksternal (vfat/exfat/ntfs = flash/SD)
      final isFlash = ['vfat', 'exfat', 'ntfs', 'fuse', 'fuseblk']
          .contains(fsType.toLowerCase());
      final isStorage = mountPoint.startsWith('/storage/') ||
          mountPoint.startsWith('/mnt/media_rw/');

      if (!isFlash || !isStorage) continue;
      if (mountPoint.contains('emulated')) continue;
      if (seen.contains(mountPoint)) continue;

      seen.add(mountPoint);
      final label = mountPoint.split('/').last;
      // Coba deteksi apakah USB atau SD berdasarkan path
      final isUsb = mountPoint.contains('usb') ||
          mountPoint.contains('otg') ||
          mountPoint.startsWith('/mnt/media_rw/');
      result.add(_StorageTab(
        label: isUsb ? 'USB ($label)' : 'SD ($label)',
        icon:  isUsb ? Icons.usb_rounded : Icons.sd_card_rounded,
        root:  mountPoint,
      ));
    }
  } catch (_) {}

  // Method 2: Scan /storage/ sebagai fallback
  if (result.isEmpty) {
    try {
      final storageDir = Directory('/storage');
      if (storageDir.existsSync()) {
        for (final entry in storageDir.listSync().whereType<Directory>()) {
          final name = entry.path.split('/').last;
          if (name == 'emulated' || name == 'self') continue;
          if (seen.contains(entry.path)) continue;
          seen.add(entry.path);
          result.add(_StorageTab(
            label: name,
            icon:  Icons.usb_rounded,
            root:  entry.path,
          ));
        }
      }
    } catch (_) {}
  }

  return result;
}

class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({super.key});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late List<_StorageTab> _tabs;

  final Map<int, String>       _paths   = {};
  final Map<int, List<String>> _history = {};

  @override
  void initState() {
    super.initState();
    _buildTabs();
    _tabCtrl = TabController(length: _tabs.length, vsync: this)
      ..addListener(() { if (!_tabCtrl.indexIsChanging) setState(() {}); });
    for (int i = 0; i < _tabs.length; i++) {
      _paths[i]   = _tabs[i].root;
      _history[i] = [];
    }
  }

  void _buildTabs() {
    final external = _findExternalTabs();
    _tabs = [
      const _StorageTab(
          label: 'Internal',
          icon:  Icons.phone_android_rounded,
          root:  '/storage/emulated/0'),
      ...external,
      const _StorageTab(
          label: 'System',
          icon:  Icons.folder_special_rounded,
          root:  '/'),
    ];
  }

  // Refresh tab storage (untuk re-scan setelah OTG dicolok)
  void _refreshTabs() {
    setState(() {
      _buildTabs();
      _tabCtrl.dispose();
      _tabCtrl = TabController(length: _tabs.length, vsync: this)
        ..addListener(() { if (!_tabCtrl.indexIsChanging) setState(() {}); });
      _paths.clear();
      _history.clear();
      for (int i = 0; i < _tabs.length; i++) {
        _paths[i]   = _tabs[i].root;
        _history[i] = [];
      }
    });
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  int    get _idx         => _tabCtrl.index;
  String get _currentPath => _paths[_idx] ?? _tabs[_idx].root;
  bool   get _canGoBack   => (_history[_idx]?.isNotEmpty) ?? false;

  void _navigate(int tabIdx, String path) {
    setState(() {
      _history[tabIdx]!.add(_paths[tabIdx]!);
      _paths[tabIdx] = path;
    });
  }

  void _goBack() {
    if (!_canGoBack) return;
    setState(() => _paths[_idx] = _history[_idx]!.removeLast());
  }

  List<Directory> _listDirs(String path) {
    try {
      return Directory(path).listSync().whereType<Directory>()
          .where((d) => !d.path.split('/').last.startsWith('.')).toList()
        ..sort((a, b) => a.path.split('/').last.toLowerCase()
            .compareTo(b.path.split('/').last.toLowerCase()));
    } catch (_) { return []; }
  }

  bool _pathExists(String p) {
    try { return Directory(p).existsSync(); } catch (_) { return false; }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dirs = _listDirs(_currentPath);
    final tabExists = _pathExists(_currentPath);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Folder',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // Tombol refresh untuk re-scan storage (berguna saat OTG dicolok setelah app buka)
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Scan ulang storage',
            onPressed: _refreshTabs,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) => Tab(
            icon: Icon(t.icon, size: 16),
            text: t.label,
          )).toList(),
        ),
      ),
      body: Column(children: [
        // Breadcrumb
        Container(
          color: cs.surfaceVariant.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            if (_canGoBack)
              GestureDetector(
                onTap: _goBack,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 14, color: cs.primary),
                ),
              ),
            Icon(Icons.folder_rounded,
                size: 14, color: Colors.amber.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_currentPath,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),

        // List folder atau pesan error
        Expanded(
          child: !tabExists
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storage_rounded,
                        size: 48, color: cs.onSurfaceVariant.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text('Storage tidak ditemukan',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text('Pastikan OTG/SD sudah terpasang\nlalu tekan tombol refresh ↻',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant.withOpacity(0.6))),
                  ],
                ))
              : dirs.isEmpty
                  ? Center(child: Text('Folder kosong',
                      style: TextStyle(color: cs.onSurfaceVariant)))
                  : ListView.builder(
                      itemCount: dirs.length,
                      itemBuilder: (_, i) {
                        final name = dirs[i].path.split('/').last;
                        return ListTile(
                          leading: Icon(Icons.folder_rounded,
                              color: Colors.amber.shade600),
                          title: Text(name),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _navigate(_idx, dirs[i].path),
                        );
                      },
                    ),
        ),
      ]),

      // FAB pilih folder ini
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context, _currentPath),
        icon: const Icon(Icons.check_rounded),
        label: const Text('Pilih Folder Ini'),
      ),
    );
  }
}
