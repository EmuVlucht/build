import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/settings_model.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final String selectedFolder;
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
    this.selectedFolder = '/sdcard',
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _s;
  late TextEditingController _portCtrl;
  late TextEditingController _authUserCtrl;
  late TextEditingController _authPassCtrl;
  bool _authEnabled = false;
  bool _authPassVisible = false;
  late TextEditingController _authUpUserCtrl;
  late TextEditingController _authUpPassCtrl;
  bool _authUpEnabled = false;
  bool _authUpPassVisible = false;

  @override
  void initState() {
    super.initState();
    _s = widget.settings;
    _portCtrl = TextEditingController(text: _s.port == 8000 ? '' : '${_s.port}');

    final authParts = _s.basicAuth.split(':');
    _authEnabled  = _s.basicAuth.isNotEmpty;
    _authUserCtrl = TextEditingController(text: authParts.isNotEmpty ? authParts[0] : '');
    _authPassCtrl = TextEditingController(
        text: authParts.length >= 2 ? authParts.sublist(1).join(':') : '');

    final authUpParts = _s.basicAuthUpload.split(':');
    _authUpEnabled  = _s.basicAuthUpload.isNotEmpty;
    _authUpUserCtrl = TextEditingController(text: authUpParts.isNotEmpty ? authUpParts[0] : '');
    _authUpPassCtrl = TextEditingController(
        text: authUpParts.length >= 2 ? authUpParts.sublist(1).join(':') : '');
  }

  @override
  void dispose() {
    _portCtrl.dispose();
    _authUserCtrl.dispose(); _authPassCtrl.dispose();
    _authUpUserCtrl.dispose(); _authUpPassCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8000;
    String basicAuth = '';
    if (_authEnabled) {
      final u = _authUserCtrl.text.trim();
      final p = _authPassCtrl.text;
      if (u.isNotEmpty && p.isNotEmpty) basicAuth = '$u:$p';
    }
    String basicAuthUpload = '';
    if (_authUpEnabled) {
      final u = _authUpUserCtrl.text.trim();
      final p = _authUpPassCtrl.text;
      if (u.isNotEmpty && p.isNotEmpty) basicAuthUpload = '$u:$p';
    }
    final updated = _s.copyWith(
      port: port.clamp(1, 65535),
      basicAuth: basicAuth,
      basicAuthUpload: basicAuthUpload,
      keepAlive: _s.keepAlive,
    );
    widget.onChanged(updated);
    Navigator.pop(context);
  }

  void _setTheme(ThemeMode m) {
    setState(() => _s = _s.copyWith(themeMode: m));
    widget.onChanged(_s);
  }

  String get _cmdPreview {
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8000;
    final parts = [
      'python -m uploadserver',
      '  --bind 0.0.0.0',
      '  --directory ${widget.selectedFolder}',
      '  --theme ${_s.themeArg}',
    ];
    if (_authEnabled && _authUserCtrl.text.isNotEmpty && _authPassCtrl.text.isNotEmpty) {
      parts.add('  --basic-auth ${_authUserCtrl.text}:${'•' * _authPassCtrl.text.length}');
    }
    if (_authUpEnabled && _authUpUserCtrl.text.isNotEmpty && _authUpPassCtrl.text.isNotEmpty) {
      parts.add('  --basic-auth-upload ${_authUpUserCtrl.text}:${'•' * _authUpPassCtrl.text.length}');
    }
    parts.add('  $port');
    return parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _sectionLabel('Tampilan'),
          _card([_themeTile(cs)]),

          _sectionLabel('Latar Belakang'),
          _card([
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          size: 18, color: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tetap Aktif di Background',
                            style: TextStyle(fontSize: 15)),
                        Text('Server tetap jalan meski app ditutup',
                            style: TextStyle(fontSize: 11,
                                color: cs.onSurfaceVariant)),
                      ],
                    )),
                    Switch(
                      value: _s.keepAlive,
                      onChanged: (v) {
                        setState(() => _s = _s.copyWith(keepAlive: v));
                        widget.onChanged(_s);
                      },
                    ),
                  ]),
                  // Hint saat aktif
                  if (_s.keepAlive) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.notifications_outlined,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'Notifikasi permanen akan muncul selama server aktif',
                          style: TextStyle(fontSize: 11,
                              color: Colors.green.shade700, height: 1.4),
                        )),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ]),

          _sectionLabel('Server'),
          _card([
            _expandTile(
              icon: Icons.lan_outlined, iconColor: cs.primary,
              title: 'Port', subtitle: 'Default 8000 jika dikosongkan',
              child: _inputWrap(
                prefix: ':', suffix: 'PORT',
                child: TextField(
                  controller: _portCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: _monoStyle(context),
                  decoration: _inputDeco('8000'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const Divider(height: 1),
            _authTile(
              icon: Icons.lock_outline, iconColor: cs.error,
              title: 'Basic Auth', subtitle: 'Proteksi download & upload',
              enabled: _authEnabled, onToggle: (v) => setState(() => _authEnabled = v),
              userCtrl: _authUserCtrl, passCtrl: _authPassCtrl,
              passVisible: _authPassVisible,
              onPassToggle: () => setState(() => _authPassVisible = !_authPassVisible),
            ),
            const Divider(height: 1),
            _authTile(
              icon: Icons.lock_clock_outlined, iconColor: Colors.orange.shade700,
              title: 'Auth Upload Saja', subtitle: 'Hanya proteksi upload',
              enabled: _authUpEnabled, onToggle: (v) => setState(() => _authUpEnabled = v),
              userCtrl: _authUpUserCtrl, passCtrl: _authUpPassCtrl,
              passVisible: _authUpPassVisible,
              onPassToggle: () => setState(() => _authUpPassVisible = !_authUpPassVisible),
            ),
          ]),

          _sectionLabel('Preview Command'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withOpacity(0.3))),
              child: SelectableText(_cmdPreview,
                style: TextStyle(fontFamily: 'monospace', fontSize: 11,
                    color: cs.onSurfaceVariant, height: 1.7)),
            ),
          ),

          _sectionLabel('Tentang'),
          _card([
            ListTile(
              leading: Icon(Icons.info_outline, color: cs.primary),
              title: const Text('Versi'),
              subtitle: const Text('NetShelfy+ for Android'),
              trailing: Text('1.0.1',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: cs.onSurfaceVariant)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(label.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            letterSpacing: 1.5, color: Theme.of(context).colorScheme.primary)),
    );
  }

  Widget _card(List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outline.withOpacity(0.25))),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  Widget _themeTile(ColorScheme cs) {
    final modes = [
      (ThemeMode.light,  'Terang', Icons.light_mode_outlined),
      (ThemeMode.system, 'Sistem', Icons.brightness_auto_outlined),
      (ThemeMode.dark,   'Gelap',  Icons.dark_mode_outlined),
    ];
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.palette_outlined, size: 22, color: cs.primary),
          const SizedBox(width: 12),
          const Text('Tema', style: TextStyle(fontSize: 15)),
        ]),
        const SizedBox(height: 14),
        Row(children: modes.map((item) {
          final (mode, label, icon) = item;
          final selected = _s.themeMode == mode;
          return Expanded(child: GestureDetector(
            onTap: () => _setTheme(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: selected ? cs.primaryContainer : cs.surfaceVariant.withOpacity(0.4),
                border: Border.all(
                  color: selected ? cs.primary : cs.outline.withOpacity(0.3),
                  width: selected ? 1.5 : 1)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 22, color: selected ? cs.primary : cs.onSurfaceVariant),
                const SizedBox(height: 6),
                Text(label, style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  color: selected ? cs.primary : cs.onSurfaceVariant)),
              ]),
            ),
          ));
        }).toList()),
      ]),
    );
  }

  Widget _expandTile({
    required IconData icon, required Color iconColor,
    required String title, required String subtitle, required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15)),
            Text(subtitle, style: TextStyle(fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _authTile({
    required IconData icon, required Color iconColor,
    required String title, required String subtitle,
    required bool enabled, required ValueChanged<bool> onToggle,
    required TextEditingController userCtrl, required TextEditingController passCtrl,
    required bool passVisible, required VoidCallback onPassToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15)),
            Text(subtitle, style: TextStyle(fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
          Switch(value: enabled, onChanged: onToggle),
        ]),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: enabled ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fieldLabel('Username'),
                _inputWrap(child: TextField(
                  controller: userCtrl, style: _monoStyle(context),
                  decoration: _inputDeco('admin'),
                  onChanged: (_) => setState(() {}),
                )),
              ])),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fieldLabel('Password'),
                _inputWrap(
                  suffixWidget: IconButton(
                    icon: Icon(passVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    onPressed: onPassToggle,
                  ),
                  child: TextField(
                    controller: passCtrl, obscureText: !passVisible,
                    style: _monoStyle(context),
                    decoration: _inputDeco('••••••'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ])),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _inputWrap({String? prefix, String? suffix, Widget? suffixWidget, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(10),
        color: cs.surfaceVariant.withOpacity(0.3)),
      child: Row(children: [
        if (prefix != null)
          Container(padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(prefix, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: cs.onSurfaceVariant))),
        Expanded(child: child),
        if (suffix != null)
          Container(padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(suffix, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: cs.onSurfaceVariant))),
        if (suffixWidget != null)
          Padding(padding: const EdgeInsets.only(right: 4), child: suffixWidget),
      ]),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text.toUpperCase(), style: TextStyle(
        fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1,
        color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }

  TextStyle _monoStyle(BuildContext ctx) =>
      TextStyle(fontFamily: 'monospace', fontSize: 13, color: Theme.of(ctx).colorScheme.onSurface);

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
        fontFamily: 'monospace', fontSize: 13),
    border: InputBorder.none,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    isDense: true,
  );
}
