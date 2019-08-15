// lib/services/update_service.dart
//
// Cek update dari GitHub Releases:
//   GET https://api.github.com/repos/OWNER/REPO/releases/latest
//   Bandingkan tag_name dengan versi app saat ini
//   Kalau ada update → download APK → trigger Android installer

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ════════════════════════════════════════════════════════════════
// KONFIGURASI — ganti sesuai repo kamu
// ════════════════════════════════════════════════════════════════
const _kGithubOwner = 'cloudy-claude';   // username GitHub kamu
const _kGithubRepo  = 'release';       // nama repo
const _kApkAsset    = 'app-release.apk'; // nama file APK di Release
// ════════════════════════════════════════════════════════════════

class UpdateInfo {
  final String tagName;       // misal "v1.2.0"
  final String version;       // misal "1.2.0"
  final int buildNumber;      // misal 2
  final String downloadUrl;
  final String? releaseNotes;

  const UpdateInfo({
    required this.tagName,
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    this.releaseNotes,
  });
}

class UpdateService {
  static const _updateChannel = MethodChannel('com.twos.netshelfy.verseapp/update');

  // ── Cek apakah ada update ──────────────────────────────────────
  /// Return null  = tidak ada update / gagal cek
  /// Return UpdateInfo = ada update tersedia
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final apiUrl = 'https://api.github.com/repos/$_kGithubOwner/$_kGithubRepo/releases/latest';

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(Uri.parse(apiUrl));
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'UploadServerApp');
      final resp = await req.close();

      if (resp.statusCode != 200) return null;

      final body = await resp.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(body) as Map<String, dynamic>;

      final tagName = json['tag_name'] as String? ?? '';
      final releaseBody = json['body'] as String?;

      // Parse build number dari tag — format: v{version}+{build} atau v{version}
      // Contoh: "v1.2.0+5" → build=5, "v1.2.0" → build=1
      int remoteBuild = 1;
      String remoteVersion = tagName.replaceFirst('v', '');
      if (tagName.contains('+')) {
        final parts = tagName.split('+');
        remoteVersion = parts[0].replaceFirst('v', '');
        remoteBuild = int.tryParse(parts[1]) ?? 1;
      }

      // Tidak ada update jika build number sama atau lebih kecil
      if (remoteBuild <= currentBuild) return null;

      // Cari URL APK di assets release
      final assets = json['assets'] as List<dynamic>? ?? [];
      String? downloadUrl;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name == _kApkAsset) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (downloadUrl == null) return null;

      return UpdateInfo(
        tagName:      tagName,
        version:      remoteVersion,
        buildNumber:  remoteBuild,
        downloadUrl:  downloadUrl,
        releaseNotes: releaseBody,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Download APK ───────────────────────────────────────────────
  /// [onProgress] dipanggil dengan nilai 0.0–1.0
  static Future<String?> downloadApk(
    String url, {
    void Function(double)? onProgress,
  }) async {
    try {
      final client = HttpClient();
      final req  = await client.getUrl(Uri.parse(url));
      final resp = await req.close();

      if (resp.statusCode != 200) return null;

      // Simpan ke cache internal app
      final dir = Directory(
        '${(await _getCacheDir())}/updates',
      );
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final file = File('${dir.path}/update.apk');
      if (file.existsSync()) file.deleteSync();

      final total    = resp.contentLength;
      int downloaded = 0;
      final sink     = file.openWrite();

      await for (final chunk in resp) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress(downloaded / total);
        }
      }

      await sink.close();
      client.close();

      return file.path;
    } catch (_) {
      return null;
    }
  }

  // ── Trigger Android package installer ─────────────────────────
  static Future<bool> installApk(String apkPath) async {
    try {
      await _updateChannel.invokeMethod('installApk', {'path': apkPath});
      return true;
    } on PlatformException catch (_) {
      return false;
    }
  }

  // ── Helper: cache dir ──────────────────────────────────────────
  static Future<String> _getCacheDir() async {
    // Coba beberapa path cache internal Android yang umum
    final candidates = [
      '/data/user/0/com.twos.netshelfy.verseapp/cache',
      '/data/data/com.twos.netshelfy.verseapp/cache',
    ];
    for (final p in candidates) {
      try {
        final d = Directory(p);
        if (!d.existsSync()) d.createSync(recursive: true);
        if (d.existsSync()) return p;
      } catch (_) {}
    }
    return Directory.systemTemp.path;
  }
}
