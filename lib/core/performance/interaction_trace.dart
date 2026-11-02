import 'dart:convert';
import 'dart:developer' as developer;

/// Opt-in QA only. No file names, paths, or content are recorded.
class InteractionTrace {
  static const enabled = bool.fromEnvironment('TAGSHELF_PERFORMANCE_TRACE');
  static final _active = <String, Stopwatch>{};

  static T sync<T>(String name, T Function() action) {
    if (!enabled) return action();
    return developer.Timeline.timeSync(name, action);
  }

  static Future<T> async<T>(String name, Future<T> Function() action) async {
    if (!enabled) return action();
    final task = developer.TimelineTask()..start(name);
    try {
      return await action();
    } finally {
      task.finish();
    }
  }

  static void start(String name) {
    if (enabled) _active[name] = Stopwatch()..start();
  }

  static void finish(String name) {
    if (!enabled) return;
    final watch = _active.remove(name);
    if (watch == null) return;
    developer.log(
      'TAGSHELF_PERF ${jsonEncode({'kind': name, 'us': watch.elapsedMicroseconds})}',
      name: 'CharmShelf.perf',
    );
  }

  static void cancel(String name) {
    if (enabled) _active.remove(name);
  }
}
