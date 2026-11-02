import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show FlutterExceptionHandler;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Standalone native QA entry point, without app.main or test bindings.
// Use only the exact QA package on its dedicated Simulator with the known
// synthetic opaque 2x2 PNG. The guarded XCUITest must start the request, decline
// notifications, cancel the first picker, and select that metadata-matched PNG.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AppleDependencyQaApp());
}

class _AppleDependencyQaApp extends StatefulWidget {
  const _AppleDependencyQaApp();

  @override
  State<_AppleDependencyQaApp> createState() => _AppleDependencyQaAppState();
}

class _AppleDependencyQaAppState extends State<_AppleDependencyQaApp> {
  static const _allowedPackage =
      'org.charmshelf.opensource.dependencyqa2026102702';
  static const _sourceHash = String.fromEnvironment(
    'TAGSHELF_DEPENDENCY_QA_SOURCE_HASH',
  );
  static const _expectedRgbaHash = String.fromEnvironment(
    'TAGSHELF_APPLE_QA_RGBA_SHA256',
  );

  String _packageName = '';
  String _stage = 'guard';
  String _message = 'Checking the dedicated QA environment';
  File? _reportFile;
  Completer<void>? _hostStart;
  Timer? _deadline;
  bool _showStart = false;
  bool _completed = false;
  bool _frameworkFailed = false;
  FlutterExceptionHandler? _previousFlutterError;
  late final FlutterExceptionHandler _qaFlutterError;

  @override
  void initState() {
    super.initState();
    _previousFlutterError = FlutterError.onError;
    _qaFlutterError = (details) {
      // Match the test harness's failure on framework errors. Do not serialize
      // arbitrary exception strings, file paths, or selected-image metadata.
      _frameworkFailed = true;
      scheduleMicrotask(() => _complete(false));
    };
    FlutterError.onError = _qaFlutterError;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_run());
    });
  }

  // Unlike assert/expect, these checks remain active in a Release QA build.
  void _check(bool condition, String fixedReason) {
    if (!condition) throw StateError(fixedReason);
  }

  void _requireActive() {
    _check(mounted && !_completed, 'QA run is no longer active');
    _check(!_frameworkFailed, 'Flutter reported a framework error');
  }

  Future<T> _bounded<T>(
    Future<T> Function() operation,
    Duration timeout, {
    void Function(T)? onDiscard,
  }) async {
    _requireActive();
    final pending = operation();
    var accepted = false;
    try {
      final result = await pending.timeout(timeout);
      // A timed-out overall run must never continue to another native operation
      // if an already-started callback subsequently completes.
      _requireActive();
      accepted = true;
      return result;
    } finally {
      if (!accepted && onDiscard != null) {
        // Resource-producing work cannot be cancelled by Future.timeout. Reap
        // its late result after a local timeout, watchdog, or framework failure.
        unawaited(
          pending.then<void>(onDiscard, onError: (Object _, StackTrace _) {}),
        );
      }
    }
  }

  void _report(String event, [Map<String, Object?> fields = const {}]) {
    final entry = jsonEncode({
      'schema': 1,
      'sourceHash': _sourceHash,
      'packageName': _packageName,
      'stage': _stage,
      'event': event,
      'pid': pid,
      ...fields,
    });
    // ignore: avoid_print
    print('TAGSHELF_APPLE_DEPENDENCY_QA $entry');
    // This field is set only after the exact-package guard has passed.
    _reportFile?.writeAsStringSync(
      '$entry\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<void> _screen(String message, {bool showStart = false}) async {
    _requireActive();
    setState(() {
      _message = message;
      _showStart = showStart;
    });
    await _bounded(
      () => WidgetsBinding.instance.endOfFrame,
      const Duration(seconds: 10),
    );
  }

  void _complete(bool passed, {bool updateUi = true}) {
    if (_completed) return;
    _completed = true;
    _deadline?.cancel();
    var reportPassed = passed;
    try {
      _report('completed', {'allTestsPassed': passed});
    } catch (_) {
      // An unavailable report file cannot turn into a successful QA result.
      // No exception text is emitted because it could contain a filesystem path.
      reportPassed = false;
      _reportFile = null;
      _report('completed', {'allTestsPassed': false});
    }
    if (!reportPassed && mounted && updateUi) {
      setState(() {
        _showStart = false;
        _message = 'Dependency smoke assertions failed at $_stage';
      });
    }
  }

  Future<void> _run() async {
    if (!mounted || _completed) return;
    _deadline = Timer(const Duration(minutes: 6), () => _complete(false));
    try {
      _check(Platform.isIOS, 'Only iOS may run this QA entry point');
      _check(
        RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(_sourceHash),
        'A valid build-input source hash is required',
      );
      _check(
        RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(_expectedRgbaHash),
        'A valid synthetic RGBA hash is required',
      );
      _packageName = (await _bounded(
        PackageInfo.fromPlatform,
        const Duration(seconds: 10),
      )).packageName;
      _check(
        _packageName == _allowedPackage,
        'This harness may run only in its dedicated QA container',
      );
      final temporary = await _bounded(
        getTemporaryDirectory,
        const Duration(seconds: 10),
      );
      await _bounded(
        () => temporary.create(recursive: true),
        const Duration(seconds: 10),
      );
      _reportFile = File('${temporary.path}/apple_dependency_qa.jsonl');

      _stage = 'notification-status';
      await _screen('Checking notification status');
      final stopwatch = Stopwatch()..start();
      final notificationStatus = await _bounded(
        () => Permission.notification.status,
        const Duration(seconds: 10),
      );
      stopwatch.stop();
      _report('notification-status-returned', {
        'status': notificationStatus.name,
        'elapsedMs': stopwatch.elapsedMilliseconds,
      });
      _check(
        notificationStatus == PermissionStatus.denied,
        'The dedicated QA install must not have requested notifications',
      );

      _stage = 'notification-request-ready';
      _hostStart = Completer<void>();
      await _screen('Ready for the QA notification request', showStart: true);
      await _bounded(
        () => WidgetsBinding.instance.waitUntilFirstFrameRasterized,
        const Duration(seconds: 10),
      );
      _report('notification-request-ready');
      await _bounded(() => _hostStart!.future, const Duration(minutes: 2));
      _report('notification-request-host-started');

      _stage = 'notification-request';
      await _screen('Decline notifications only for this synthetic QA app');
      final requestStopwatch = Stopwatch()..start();
      _report('native-notification-request-opening');
      final requestedStatus = await _bounded(
        () => Permission.notification.request(),
        const Duration(seconds: 20),
      );
      requestStopwatch.stop();
      _report('notification-request-returned', {
        'status': requestedStatus.name,
        'elapsedMs': requestStopwatch.elapsedMilliseconds,
      });
      _check(
        requestedStatus == PermissionStatus.permanentlyDenied,
        'The host must decline the QA notification prompt',
      );

      final picker = ImagePicker();
      _stage = 'picker-cancel';
      await _screen('Cancel the first native image picker');
      _report('native-picker-opening');
      final cancelled = await _bounded(
        () => picker.pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        ),
        const Duration(minutes: 2),
      );
      _check(cancelled == null, 'The first native picker must be cancelled');
      _report('picker-cancel-returned-null');

      _stage = 'picker-select';
      await _screen('Select only the synthetic QA PNG');
      _report('native-picker-opening');
      final selected = await _bounded(
        () => picker.pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        ),
        const Duration(minutes: 2),
      );
      _check(selected != null, 'Select the seeded synthetic QA image');
      final bytes = await _bounded(
        selected!.readAsBytes,
        const Duration(seconds: 10),
      );
      _check(
        bytes.isNotEmpty && bytes.length <= 2 * 1024 * 1024,
        'The selected synthetic image must fit the bounded byte limit',
      );
      final codec = await _bounded(
        () => ui.instantiateImageCodec(bytes),
        const Duration(seconds: 10),
        onDiscard: (codec) => codec.dispose(),
      );
      try {
        _check(
          codec.frameCount == 1,
          'The synthetic image must have one frame',
        );
        final frame = await _bounded(
          codec.getNextFrame,
          const Duration(seconds: 10),
          onDiscard: (frame) => frame.image.dispose(),
        );
        try {
          _check(
            frame.image.width == 2 && frame.image.height == 2,
            'Only the synthetic 2x2 image may be selected',
          );
          final rgba = await _bounded(
            () => frame.image.toByteData(format: ui.ImageByteFormat.rawRgba),
            const Duration(seconds: 10),
          );
          _check(rgba != null, 'RGBA decoding must return data');
          final data = rgba!;
          final pixels = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          _check(
            pixels.length == 16,
            'The synthetic RGBA must contain 16 bytes',
          );
          _check(
            sha256.convert(pixels).toString() ==
                _expectedRgbaHash.toLowerCase(),
            'Only the decoded synthetic fixture may be selected',
          );
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
      _report('picker-select-returned-synthetic-image');

      _stage = 'notification-status-after-picker';
      final afterPicker = await _bounded(
        () => Permission.notification.status,
        const Duration(seconds: 10),
      );
      _check(
        afterPicker == requestedStatus,
        'The status callback after picker dismissal must match the request',
      );
      _report('notification-status-returned', {'status': afterPicker.name});
      _stage = 'finished';
      await _screen('Dependency smoke assertions passed');
      _complete(true);
    } catch (_) {
      _complete(false);
    }
  }

  void _onHostStart() {
    if (!mounted || _completed || _frameworkFailed || !_showStart) return;
    final start = _hostStart;
    if (start != null && !start.isCompleted) {
      setState(() => _showStart = false);
      start.complete();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('CharmShelf dependency QA'),
                const SizedBox(height: 16),
                Text(_message, textAlign: TextAlign.center),
                if (_showStart) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _onHostStart,
                    child: const Text('Request QA notification permission'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _complete(false, updateUi: false);
    if (identical(FlutterError.onError, _qaFlutterError)) {
      FlutterError.onError = _previousFlutterError;
    }
    super.dispose();
  }
}
