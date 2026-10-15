import 'dart:collection';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/scheduler.dart';

import '../device/display_info.dart';

const int _maxFrames = 600;

/// Drop the first N ms after [FrameProbe.start] so cold-start frames do not
/// poison session P95.
const int _warmupMs = 3000;

/// Rolling window for "recent" percentiles / jank density.
const int _recentWindowMs = 10000;

/// Minimum recent fps before jank% is considered meaningful.
const double _minJankFps = 10;

/// Frames closer than this multiple of the budget count as "back-to-back"
/// (continuous animation / scroll), not sparse idle ticks.
const double _denseGapBudgetMul = 2.5;

/// A single rendered frame, measured by the engine.
class FrameSample {
  const FrameSample({
    required this.buildMs,
    required this.rasterMs,
    required this.vsyncMs,
    required this.totalMs,
    required this.jank,
    required this.atMs,
  });

  final double buildMs;
  final double rasterMs;
  final double vsyncMs;
  final double totalMs;
  final bool jank;

  /// Wall-clock ms when this sample was recorded (for windowing / density).
  final int atMs;

  Map<String, Object?> toJson() => <String, Object?>{
        'buildMs': buildMs,
        'rasterMs': rasterMs,
        'vsyncMs': vsyncMs,
        'totalMs': totalMs,
        'jank': jank,
        'atMs': atMs,
      };
}

/// Captures engine frame timings via [SchedulerBinding.addTimingsCallback].
///
/// Exposes session and recent-window P95, and gates jank% on dense back-to-back
/// frames so a 1 Hz idle clock cannot report "100% jank".
class FrameProbe {
  FrameProbe._();

  static final FrameProbe instance = FrameProbe._();

  final Queue<FrameSample> _frames = Queue<FrameSample>();
  bool _active = false;
  int? _startedAtMs;
  DisplayInfo _display = const DisplayInfo(
    refreshRate: 60,
    budgetMs: 16.666666666666668,
  );

  bool get active => _active;

  DisplayInfo get display => _display;

  void start() {
    if (_active) return;
    _active = true;
    _startedAtMs = DateTime.now().millisecondsSinceEpoch;
    _display = resolveDisplayInfo();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_active) return;
    _active = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void reset() {
    _frames.clear();
    _startedAtMs = DateTime.now().millisecondsSinceEpoch;
    _display = resolveDisplayInfo();
  }

  /// Feeds timings directly — for unit tests only.
  @visibleForTesting
  void debugAddTimings(List<FrameTiming> timings, {int? atMs}) =>
      _onTimings(timings, atMsOverride: atMs);

  /// Anchors the warmup clock — for unit tests only.
  @visibleForTesting
  void debugSetStartedAtMs(int ms) => _startedAtMs = ms;

  void _onTimings(List<FrameTiming> timings, {int? atMsOverride}) {
    final double budgetMs = _display.budgetMs;
    final int nowMs = atMsOverride ?? DateTime.now().millisecondsSinceEpoch;
    for (final FrameTiming timing in timings) {
      final double totalMs = timing.totalSpan.inMicroseconds / 1000.0;
      _frames.addLast(
        FrameSample(
          buildMs: _round(timing.buildDuration.inMicroseconds / 1000.0),
          rasterMs: _round(timing.rasterDuration.inMicroseconds / 1000.0),
          vsyncMs: _round(timing.vsyncOverhead.inMicroseconds / 1000.0),
          totalMs: _round(totalMs),
          jank: totalMs > budgetMs,
          atMs: nowMs,
        ),
      );
      while (_frames.length > _maxFrames) {
        _frames.removeFirst();
      }
    }
  }

  List<FrameSample> _afterWarmup(List<FrameSample> all) {
    final int? start = _startedAtMs;
    if (start == null) return all;
    final int cutoff = start + _warmupMs;
    return all.where((FrameSample f) => f.atMs >= cutoff).toList();
  }

  List<FrameSample> _inWindow(List<FrameSample> samples, int nowMs, int windowMs) {
    final int cutoff = nowMs - windowMs;
    return samples.where((FrameSample f) => f.atMs >= cutoff).toList();
  }

  /// Frames delivered back-to-back (gap ≤ budget × [_denseGapBudgetMul]).
  List<FrameSample> _denseFrames(List<FrameSample> samples) {
    if (samples.length < 2) return <FrameSample>[];
    final double maxGapMs = _display.budgetMs * _denseGapBudgetMul;
    final List<bool> keep = List<bool>.filled(samples.length, false);
    for (var i = 1; i < samples.length; i++) {
      final int gap = samples[i].atMs - samples[i - 1].atMs;
      if (gap >= 0 && gap <= maxGapMs) {
        keep[i - 1] = true;
        keep[i] = true;
      }
    }
    return <FrameSample>[
      for (var i = 0; i < samples.length; i++)
        if (keep[i]) samples[i],
    ];
  }

  double _fpsOf(List<FrameSample> samples) {
    if (samples.length < 2) return 0;
    final int spanMs = samples.last.atMs - samples.first.atMs;
    if (spanMs <= 0) return 0;
    return ((samples.length - 1) / spanMs) * 1000.0;
  }

  Map<String, Object?> snapshot({int limit = 120}) {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final List<FrameSample> all = _frames.toList();
    final List<FrameSample> session = _afterWarmup(all);
    final List<FrameSample> recent = _inWindow(session, nowMs, _recentWindowMs);
    final List<FrameSample> forFrames =
        recent.length <= limit ? recent : recent.sublist(recent.length - limit);

    final List<FrameSample> denseRecent = _denseFrames(recent);
    final double recentFps = _fpsOf(recent);
    final bool jankInconclusive =
        recentFps < _minJankFps || denseRecent.length < 6;
    final List<FrameSample> jankSource =
        jankInconclusive ? <FrameSample>[] : denseRecent;
    final int jankCount = jankSource.where((FrameSample f) => f.jank).length;
    final double jankRatio =
        jankSource.isEmpty ? 0 : jankCount / jankSource.length;

    return <String, Object?>{
      'ok': true,
      'active': _active,
      'refreshRate': _display.refreshRate,
      'budgetMs': _display.budgetMs,
      'warmupMs': _warmupMs,
      'windowMs': _recentWindowMs,
      'count': forFrames.length,
      'sessionCount': session.length,
      'recentCount': recent.length,
      'jank': jankCount,
      'jankRatio': _round(jankRatio),
      'jankInconclusive': jankInconclusive,
      'jankDenseCount': denseRecent.length,
      'recentFps': _round(recentFps),
      // Backward-compatible: p95 is the recent-window value (steady-state).
      'p95': _percentiles(recent),
      'p95Session': _percentiles(session),
      'p95Recent': _percentiles(recent),
      'frames': forFrames.map((FrameSample f) => f.toJson()).toList(),
    };
  }

  Map<String, double> _percentiles(List<FrameSample> samples) {
    if (samples.isEmpty) {
      return const <String, double>{'buildMs': 0, 'rasterMs': 0, 'totalMs': 0};
    }
    return <String, double>{
      'buildMs': _round(_p95(samples.map((FrameSample f) => f.buildMs).toList())),
      'rasterMs':
          _round(_p95(samples.map((FrameSample f) => f.rasterMs).toList())),
      'totalMs': _round(_p95(samples.map((FrameSample f) => f.totalMs).toList())),
    };
  }
}

double _p95(List<double> values) {
  if (values.isEmpty) return 0;
  final List<double> sorted = <double>[...values]..sort();
  final int index = ((sorted.length - 1) * 0.95).round();
  return sorted[index];
}

double _round(double value) => double.parse(value.toStringAsFixed(2));
