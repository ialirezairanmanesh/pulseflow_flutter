import 'dart:collection';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/scheduler.dart';

/// One detected main-isolate stall (UI freeze).
class StallEvent {
  StallEvent({
    required this.id,
    required this.durationMs,
    required this.atMs,
    this.route,
    this.kind,
  });

  final String id;
  final double durationMs;
  final int atMs;
  final String? route;

  /// `vsync` = blocked before build started; `build` = blocked during build.
  final String? kind;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'durationMs': durationMs,
        'atMs': atMs,
        if (route != null) 'route': route,
        if (kind != null) 'kind': kind,
      };
}

/// Detects main-isolate freezes from [FrameTiming] of frames that were
/// actually scheduled.
///
/// A stall is recorded when, for a delivered frame:
/// - [FrameTiming.vsyncOverhead] ≥ threshold (isolate busy after vsync before
///   build could start), or
/// - [FrameTiming.buildDuration] ≥ threshold (isolate blocked during build).
///
/// Quiet periods with **no scheduled frame** (static screens, 1 Hz clocks) are
/// idleness — never stalls. This replaces the old `Timer.periodic` gap detector,
/// which fired whenever the engine parked the UI isolate between frames.
class StallProbe {
  StallProbe._();

  static final StallProbe instance = StallProbe._();

  final Queue<StallEvent> _events = Queue<StallEvent>();
  bool _active = false;
  int _seq = 0;
  Duration threshold = const Duration(milliseconds: 250);
  String? Function()? routeProvider;

  bool get active => _active;

  void start({Duration? threshold}) {
    if (threshold != null) this.threshold = threshold;
    if (_active) return;
    _active = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_active) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _active = false;
  }

  void reset() {
    _events.clear();
    _seq = 0;
  }

  void _onTimings(List<FrameTiming> timings) {
    final double thresholdMs = threshold.inMilliseconds.toDouble();
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final FrameTiming timing in timings) {
      final double vsyncMs = timing.vsyncOverhead.inMicroseconds / 1000.0;
      final double buildMs = timing.buildDuration.inMicroseconds / 1000.0;

      String? kind;
      double stallMs = 0;
      if (vsyncMs >= thresholdMs && vsyncMs >= buildMs) {
        kind = 'vsync';
        stallMs = vsyncMs;
      } else if (buildMs >= thresholdMs) {
        kind = 'build';
        stallMs = buildMs;
      } else {
        continue;
      }

      _events.addLast(
        StallEvent(
          id: 'stall-${++_seq}',
          durationMs: double.parse(stallMs.toStringAsFixed(1)),
          atMs: nowMs,
          route: routeProvider?.call(),
          kind: kind,
        ),
      );
      while (_events.length > 100) {
        _events.removeFirst();
      }
    }
  }

  /// Test hook: record a synthetic stall without waiting on the engine.
  @visibleForTesting
  void debugRecordStall({
    required double durationMs,
    String? route,
    String kind = 'build',
  }) {
    _events.addLast(
      StallEvent(
        id: 'stall-${++_seq}',
        durationMs: durationMs,
        atMs: DateTime.now().millisecondsSinceEpoch,
        route: route,
        kind: kind,
      ),
    );
  }

  /// Test hook: feed engine timings directly.
  @visibleForTesting
  void debugAddTimings(List<FrameTiming> timings) => _onTimings(timings);

  Map<String, Object?> report({int limit = 40}) {
    final List<StallEvent> all = _events.toList();
    final List<StallEvent> recent =
        all.length <= limit ? all : all.sublist(all.length - limit);
    final double maxMs = recent.isEmpty
        ? 0
        : recent
            .map((StallEvent e) => e.durationMs)
            .reduce((double a, double b) => a > b ? a : b);
    return <String, Object?>{
      'ok': true,
      'available': true,
      'active': _active,
      'thresholdMs': threshold.inMilliseconds,
      'total': all.length,
      'maxDurationMs': maxMs,
      'detector': 'frameTiming',
      'framePhase': SchedulerBinding.instance.schedulerPhase.name,
      'stalls': recent.map((StallEvent e) => e.toJson()).toList(),
    };
  }
}
