
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Offline Android renderer backed by Geode's original C++ visualization engine.
/// Each export owns its renderer and does not mutate live player state.
class GeodeExport {
  GeodeExport._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        progress.value = ExportProgress(
          phase: data['phase'] as String,
          fraction: (data['value'] as num).toDouble().clamp(0, 1),
        );
      }
    });
  }

  static final instance = GeodeExport._();
  static const _channel = MethodChannel('dev.geode/export');
  final progress = ValueNotifier(const ExportProgress(phase: 'Ready', fraction: 0));
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<String?> render(Map<String, dynamic> project) async {
    progress.value = const ExportProgress(phase: 'Choose where to save', fraction: 0);
    return _channel.invokeMethod<String>('render', {'project': project});
  }

  Future<void> cancel() => _channel.invokeMethod<void>('cancel');

  Future<Map<String, dynamic>> importMedia(String uri, String name) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'importMedia', {'uri': uri, 'name': name},
    );
    if (result == null) throw StateError('No media was imported.');
    return result;
  }

  Future<Uint8List?> preview(Map<String, dynamic> project, String key, int atMs) =>
    _channel.invokeMethod<Uint8List>('preview', {
      'project': project, 'key': key, 'atMs': atMs,
    });

  Future<void> closePreview() => _channel.invokeMethod<void>('closePreview');
}

@immutable
class ExportProgress {
  const ExportProgress({required this.phase, required this.fraction});
  final String phase;
  final double fraction;
}
