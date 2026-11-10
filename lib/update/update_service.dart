import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Description de la dernière version publiée par la CI
/// (fichier `version.json` de la release « derniere-version »).
class ReleaseInfo {
  final int build;
  final String? commit;
  final DateTime? date;
  final String? notes;
  final int? size;

  const ReleaseInfo({required this.build, this.commit, this.date, this.notes, this.size});

  static ReleaseInfo? tryParse(String body) {
    try {
      final j = jsonDecode(body);
      if (j is! Map) return null;
      final build = j['build'];
      final b = build is int ? build : int.tryParse('$build');
      if (b == null) return null;
      final size = j['size'];
      final notes = j['notes'];
      return ReleaseInfo(
        build: b,
        commit: j['commit'] as String?,
        date: DateTime.tryParse('${j['date']}')?.toLocal(),
        notes: notes is String && notes.trim().isNotEmpty ? notes.trim() : null,
        size: size is int ? size : null,
      );
    } catch (_) {
      return null;
    }
  }

  bool isNewerThan(int installedBuild) => build > installedBuild;
}

enum UpdateStatus { idle, checking, upToDate, available, downloading, needsPermission, readyToInstall, error }

/// Vérifie si une nouvelle version de l'APK est publiée sur GitHub,
/// la télécharge et lance l'installateur Android.
class UpdateService extends ChangeNotifier with WidgetsBindingObserver {
  static const repo = 'Riary-jinxed/Course_appli';
  static const _base = 'https://github.com/$repo/releases/download/derniere-version';
  static const _channel = MethodChannel('course_appli/update');

  final http.Client _http;
  UpdateService({http.Client? client}) : _http = client ?? http.Client();

  UpdateStatus status = UpdateStatus.idle;
  int? installedBuild;
  String? installedName;
  ReleaseInfo? latest;
  double? progress; // 0..1, null si taille inconnue
  String? error;
  bool dismissed = false;
  File? _apk;
  DateTime? _lastCheck;

  bool get supported => !kIsWeb && Platform.isAndroid;
  bool get hasUpdate => latest != null && installedBuild != null && latest!.isNewerThan(installedBuild!);
  bool get busy => status == UpdateStatus.checking || status == UpdateStatus.downloading;

  /// Bandeau sur l'écran principal : nouvelle version non ignorée.
  bool get showBanner =>
      !dismissed &&
      hasUpdate &&
      status != UpdateStatus.checking &&
      status != UpdateStatus.upToDate;

  void dismiss() {
    dismissed = true;
    notifyListeners();
  }

  void start() {
    if (!supported) return;
    WidgetsBinding.instance.addObserver(this);
    check(silent: true);
  }

  void _set(UpdateStatus s) {
    status = s;
    notifyListeners();
  }

  Future<void> _loadInstalled() async {
    if (installedBuild != null) return;
    final info = await _channel.invokeMapMethod<String, dynamic>('installedVersion');
    installedBuild = (info?['code'] as num?)?.toInt();
    installedName = info?['name'] as String?;
  }

  /// Interroge la release. [silent] : pas d'erreur affichée (vérification auto).
  Future<void> check({bool silent = false}) async {
    if (!supported || busy) return;
    _lastCheck = DateTime.now();
    error = null;
    _set(UpdateStatus.checking);
    try {
      await _loadInstalled();
      final res = await _http
          .get(Uri.parse('$_base/version.json?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final info = ReleaseInfo.tryParse(utf8.decode(res.bodyBytes));
      if (info == null) throw const FormatException('version.json illisible');
      if (latest?.build != info.build) dismissed = false;
      latest = info;
      if (!hasUpdate) {
        _set(UpdateStatus.upToDate);
      } else if (_apk != null && await _apk!.exists() && _apkBuild == info.build) {
        _set(UpdateStatus.readyToInstall);
      } else {
        _set(UpdateStatus.available);
      }
    } catch (e) {
      error = silent ? null : 'Impossible de vérifier les mises à jour ($e)';
      _set(silent ? UpdateStatus.idle : UpdateStatus.error);
    }
  }

  int? _apkBuild;

  /// Télécharge l'APK puis lance l'installation.
  Future<void> update() async {
    if (!supported || busy || latest == null) return;
    error = null;
    if (!(status == UpdateStatus.readyToInstall || status == UpdateStatus.needsPermission) ||
        _apk == null ||
        !await _apk!.exists()) {
      final ok = await _download();
      if (!ok) return;
    }
    await install();
  }

  Future<bool> _download() async {
    progress = 0;
    _set(UpdateStatus.downloading);
    IOSink? sink;
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
      await dir.create(recursive: true);
      final file = File('${dir.path}/course.apk');
      final part = File('${dir.path}/course.apk.part');
      final res = await _http
          .send(http.Request('GET', Uri.parse('$_base/course.apk')))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final total = res.contentLength ?? latest?.size;
      var received = 0;
      sink = part.openWrite();
      var lastNotify = 0.0;
      await for (final chunk in res.stream.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        received += chunk.length;
        if (total != null && total > 0) {
          progress = received / total;
          if (progress! - lastNotify >= 0.01) {
            lastNotify = progress!;
            notifyListeners();
          }
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (total != null && received != total) {
        throw const HttpException('téléchargement incomplet');
      }
      if (await file.exists()) await file.delete();
      _apk = await part.rename(file.path);
      _apkBuild = latest?.build;
      progress = 1;
      _set(UpdateStatus.readyToInstall);
      return true;
    } catch (e) {
      await sink?.close();
      error = 'Échec du téléchargement ($e)';
      progress = null;
      _set(UpdateStatus.error);
      return false;
    }
  }

  /// Ouvre l'installateur Android. Si l'appli n'a pas encore le droit
  /// d'installer des applis, ouvre le réglage correspondant : l'installation
  /// reprend automatiquement au retour dans l'appli.
  Future<void> install() async {
    if (_apk == null) return;
    try {
      final allowed = await _channel.invokeMethod<bool>('canInstall') ?? false;
      if (!allowed) {
        _set(UpdateStatus.needsPermission);
        await _channel.invokeMethod('openInstallSettings');
        return;
      }
      _set(UpdateStatus.readyToInstall);
      await _channel.invokeMethod('install', {'path': _apk!.path});
    } on PlatformException catch (e) {
      error = 'Impossible de lancer l\'installation (${e.message ?? e.code})';
      _set(UpdateStatus.error);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (status == UpdateStatus.needsPermission) {
      // Retour du réglage « Installer des applis inconnues ».
      _channel.invokeMethod<bool>('canInstall').then((ok) {
        if (ok == true) install();
      });
    } else if (_lastCheck == null || DateTime.now().difference(_lastCheck!) > const Duration(hours: 6)) {
      check(silent: true);
    }
  }

  @override
  void dispose() {
    if (supported) WidgetsBinding.instance.removeObserver(this);
    _http.close();
    super.dispose();
  }
}
