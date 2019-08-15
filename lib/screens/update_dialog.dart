// lib/screens/update_dialog.dart
// Dialog yang muncul saat ada update tersedia

import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress  = 0;
  String? _error;

  Future<void> _doUpdate() async {
    setState(() { _downloading = true; _error = null; });

    final path = await UpdateService.downloadApk(
      widget.info.downloadUrl,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;

    if (path == null) {
      setState(() { _downloading = false; _error = 'Gagal mengunduh update.'; });
      return;
    }

    final ok = await UpdateService.installApk(path);
    if (!mounted) return;

    if (!ok) {
      setState(() { _downloading = false; _error = 'Gagal membuka installer.'; });
    }
    // Kalau ok: Android installer terbuka, dialog tetap di-dismiss otomatis
    // karena activity berpindah ke installer
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(children: [
        Icon(Icons.system_update_rounded, color: cs.primary),
        const SizedBox(width: 10),
        const Text('Update Tersedia'),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Versi baru
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.new_releases_rounded, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'Versi ${widget.info.version} (build ${widget.info.buildNumber})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ]),
          ),

          // Release notes
          if (widget.info.releaseNotes != null && widget.info.releaseNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Catatan:', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Text(
                  widget.info.releaseNotes!,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],

          // Progress bar saat download
          if (_downloading) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: LinearProgressIndicator(value: _progress > 0 ? _progress : null)),
              const SizedBox(width: 10),
              Text(
                _progress > 0 ? '${(_progress * 100).toInt()}%' : '...',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              _progress > 0 ? 'Mengunduh...' : 'Memulai unduhan...',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],

          // Error
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.error_outline, size: 16, color: cs.error),
              const SizedBox(width: 6),
              Expanded(child: Text(_error!, style: TextStyle(fontSize: 12, color: cs.error))),
            ]),
          ],
        ],
      ),
      actions: _downloading
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Nanti'),
              ),
              FilledButton.icon(
                onPressed: _doUpdate,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Update Sekarang'),
              ),
            ],
    );
  }
}
