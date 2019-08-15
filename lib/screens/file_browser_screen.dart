import 'dart:io';
import 'package:flutter/material.dart';

class _StorageTab {
  final String label;
  final IconData icon;
  final String root;
  const _StorageTab({required this.label, required this.icon, required this.root});
}

class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({super.key});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final _tabs = const [
    _StorageTab(label: 'Internal',    icon: Icons.phone_android_rounded, root: '/storage/emulated/0'),
    _StorageTab(label: 'Memory Card', icon: Icons.sd_card_rounded,       root: '/storage/sdcard1'),
    _StorageTab(label: 'USB Storage', icon: Icons.usb_rounded,           root: '/storage/usbdisk'),
    _StorageTab(label: 'System',      icon: Icons.folder_special_rounded, root: '/'),
  ];

  final Map<int, String>       _paths   = {};
  final Map<int, List<String>> _history = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this)
      ..addListener(() { if (!_tabCtrl.indexIsChanging) setState(() {}); });
    for (int i = 0; i < _tabs.length; i++) {
      _paths[i]   = _tabs[i].root;
      _history[i] = [];
    }
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  int    get _idx         => _tabCtrl.index;
  String get _currentPath => _paths[_idx] ?? _tabs[_idx].root;
  bool   get _canGoBack   => (_history[_idx]?.isNotEmpty) ?? false;

  void _navigate(int tabIdx, String path) {
    setState(() { _history[tabIdx]!.add(_paths[tabIdx]!); _paths[tabIdx] = path; });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Folder', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl, isScrollable: true, tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) =>
              Tab(icon: Icon(t.icon, size: 18), text: t.label, height: 56)).toList(),
        ),
      ),
      body: TabBarView(controller: _tabCtrl, children: List.generate(_tabs.length, _buildTab)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context, _currentPath),
        icon: const Icon(Icons.check_rounded),
        label: const Text('Pilih Folder Ini', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTab(int tabIdx) {
    return Builder(builder: (context) {
      final path     = _paths[tabIdx] ?? _tabs[tabIdx].root;
      final isActive = _tabCtrl.index == tabIdx;
      if (!_pathExists(path)) return _buildUnavailable(_tabs[tabIdx].label);
      final dirs = _listDirs(path);
      return Column(children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_rounded, size: 18,
                    color: (isActive && _canGoBack)
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.grey.shade400),
                onPressed: (isActive && _canGoBack) ? _goBack : null,
                padding: const EdgeInsets.all(6), constraints: const BoxConstraints()),
              const SizedBox(width: 4),
              const Icon(Icons.folder_open_rounded, size: 16, color: Colors.amber),
              const SizedBox(width: 6),
              Expanded(child: Text(path,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
        Expanded(
          child: dirs.isEmpty ? _buildEmpty()
              : ListView.separated(
                  itemCount: dirs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                  itemBuilder: (ctx, i) {
                    final name = dirs[i].path.split('/').last;
                    return ListTile(
                      leading: const Icon(Icons.folder_rounded, color: Colors.amber, size: 30),
                      title: Text(name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: () => _navigate(tabIdx, dirs[i].path),
                      dense: true,
                    );
                  }),
        ),
      ]);
    });
  }

  Widget _buildUnavailable(String label) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.storage_rounded, size: 64, color: Colors.grey.shade300),
      const SizedBox(height: 16),
      Text('$label tidak tersedia',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      Text('Storage tidak terpasang\natau tidak dapat diakses',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
    ]),
  ));

  Widget _buildEmpty() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.folder_off_rounded, size: 56, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text('Folder kosong', style: TextStyle(color: Colors.grey.shade500)),
    ]),
  ));
}
