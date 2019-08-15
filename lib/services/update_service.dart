import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _kGithubOwner = 'EmuVlucht';
const _kGithubRepo  = 'beta';
const _kApkAsset    = 'app-release.apk';

class UpdateInfo {
  final String tagName;
  final String version;
  final int buildNumber;
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

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final apiUrl = 'https://api.github.com/repos/$_kGithubOwner/$_kGithubRepo/releases/latest';
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(Uri.parse(apiUrl));
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'NetShelfyApp');
      final resp = await req.close();

      if (resp.statusCode != 200) return null;

      final body = await resp.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(body) as Map<String, dynamic>;
      final tagName    = json['tag_name'] as String? ?? '';
      final releaseBody = json['body'] as String?;

      int remoteBuild = 1;
      String remoteVersion = tagName.replaceFirst('v', '');
      if (tagName.contains('+')) {
        final parts = tagName.split('+');
        remoteVersion = parts[0].replaceFirst('v', '');
        remoteBuild = int.tryParse(parts[1]) ?? 1;
      }

      if (remoteBuild <= currentBuild) return null;

      final assets = json['assets'] as List<dynamic>? ?? [];
      String? downloadUrl;

      // Prioritas 1: universal APK
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.contains('universal') && name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
      // Prioritas 2: APK apapun yang ada
      if (downloadUrl == null) {
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String?;
            break;
          }
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

  static Future<String?> downloadApk(
    String url, {
    void Function(double)? onProgress,
  }) async {
    try {
      final client = HttpClient();
      final req  = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      if (resp.statusCode != 200) return null;

      // Pakai cache dir yang diperoleh secara dinamis
      final cacheDir = await _getCacheDir();
      final dir = Directory('$cacheDir/updates');
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

  static Future<bool> installApk(String apkPath) async {
    try {
      await _updateChannel.invokeMethod('installApk', {'path': apkPath});
      return true;
    } on PlatformException catch (_) {
      return false;
    }
  }

  static Future<String> _getCacheDir() async {
    // Dapatkan packageName secara dinamis dari PackageInfo
    try {
      final info = await PackageInfo.fromPlatform();
      final pkg  = info.packageName; // com.twos.netshelfy.verseapp
      for (final p in [
        '/data/user/0/$pkg/cache',
        '/data/data/$pkg/cache',
      ]) {
        try {
          final d = Directory(p);
          if (!d.existsSync()) d.createSync(recursive: true);
          if (d.existsSync()) return p;
        } catch (_) {}
      }
    } catch (_) {}
    return Directory.systemTemp.path;
  }
}
