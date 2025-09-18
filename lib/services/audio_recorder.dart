import 'dart:io';
import 'dart:async';
import 'dart:convert';   // pour utf8
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';


/// Enregistrement LOOPBACK → /Download/Record_Radio/
/// Compatible : Android, iOS, Windows, Linux, macOS
class AudioRecorder {
  static const MethodChannel _channel = MethodChannel('audio_recorder');

  bool _isRecording = false;
  String? _outputPath;
  Process? _desktopProcess;

  bool get isRecording => _isRecording;

  Future<String> start({String? path, Map<String, dynamic>? config}) async {
    if (_isRecording) throw Exception('Déjà en cours');

    await _requestPermissions();
    _outputPath = await _prepareOutputPath(path);

    if (kIsWeb) throw UnsupportedError('Web non supporté');

    if (Platform.isAndroid) {
      await _startAndroid();
    } else if (Platform.isIOS) {
      await _startIOS();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await _startDesktop();
    }

    _isRecording = true;
    if (_outputPath == null) throw Exception('Chemin de sortie non défini');
    return _outputPath!;
  }

  Future<String?> stop() async {
    if (!_isRecording) return null;

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await _channel.invokeMethod('stopCapture');
      } catch (_) {}
    } else {
      _desktopProcess?.kill();
      await _desktopProcess?.exitCode;
    }

    _isRecording = false;
    final path = _outputPath;
    _outputPath = null;
    return path;
  }

  /* ---------------------------------------------------------- */
  /*                 Plateformes spécifiques                    */
  /* ---------------------------------------------------------- */
  Future<void> _startAndroid() async {
    try {
      await _channel.invokeMethod('startCapture', {'path': _outputPath});
    } catch (_) {
      throw Exception('Loopback non disponible sur cet appareil');
    }
  }

  Future<void> _startIOS() async {
    try {
      await _channel.invokeMethod('startReplayKitCapture', {'path': _outputPath});
    } catch (_) {
      throw Exception('Loopback non disponible sur cet appareil');
    }
  }

  Future<void> _startDesktop() async {
    // 0. Chemin cible
    final targetFile = File(_outputPath!);
    await targetFile.create(recursive: true);

    // 1. Vérifie que Stereo Mix existe
    final check = await Process.run('ffmpeg', ['-list_devices', 'true', '-f', 'dshow', '-i', 'dummy'], runInShell: true);
    if (!check.stdout.toString().contains('Stereo Mix (Realtek(R) Audio)')) {
      throw Exception('Stereo Mix introuvable - activez-le dans les périphériques audio');
    }

    // 2. Lance FFmpeg
    final args = [
      '-f', 'dshow',
      '-i', 'audio=Stereo Mix (Realtek(R) Audio)',
      '-acodec', 'aac',
      '-b:a', '128k',
      '-ar', '44100',
      '-y',                 // écrase si existe
      _outputPath!,
    ];

    debugPrint('FFmpeg cmd : ffmpeg ${args.join(' ')}');

    _desktopProcess = await Process.start('ffmpeg', args, runInShell: true);

    // 3. Logs console
    _desktopProcess!.stdout.transform(utf8.decoder).listen((data) => debugPrint(data.toString()));
    _desktopProcess!.stderr.transform(utf8.decoder).listen((data) => debugPrint(data.toString()));
  }

  /* ---------------------------------------------------------- */
  /*                 Permissions                                  */
  /* ---------------------------------------------------------- */
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.microphone.request();
      if (await _androidVersion() >= 33) await Permission.audio.request();
    } else if (Platform.isIOS) {
      await Permission.microphone.request();
    }
  }

  Future<int> _androidVersion() async =>
      await _channel.invokeMethod('getAndroidVersion') ?? 0;

  /* ---------------------------------------------------------- */
  /*                 Chemin de sortie                           */
  /* ---------------------------------------------------------- */
  Future<String> _prepareOutputPath(String? custom) async {
    if (custom != null) return custom;

    final now = DateTime.now();
    final ts = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final ext = Platform.isIOS || Platform.isMacOS ? '.m4a' : '.aac';

    // Dossier « Downloads » officiel de l’OS
    final dirDownloads = await getDownloadsDirectory();   // package path_provider
    if (dirDownloads == null) throw Exception('Impossible d’obtenir le dossier Downloads');

    final targetDir = Directory('${dirDownloads.path}${Platform.pathSeparator}Record_Radio');
    if (!await targetDir.exists()) await targetDir.create(recursive: true);

    return '${targetDir.path}${Platform.pathSeparator}radio_$ts$ext';
  }
}