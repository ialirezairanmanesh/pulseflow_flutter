import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulseflow_flutter/pulseflow_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FrameProbe.instance.reset();
    FrameProbe.instance.stop();
  });

  int pastWarmupAt() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    FrameProbe.instance.debugSetStartedAtMs(now - 5000);
    return now;
  }

  test('records engine frame timings', () {
    final FrameProbe probe = FrameProbe.instance;
    probe.reset();
    final int at = pastWarmupAt();
    probe.debugAddTimings(<FrameTiming>[
      FrameTiming(
        vsyncStart: 0,
        buildStart: 1000,
        buildFinish: 5000,
        rasterStart: 5000,
        rasterFinish: 10000,
        rasterFinishWallTime: 11000,
      ),
    ], atMs: at);

    final Map<String, Object?> snapshot = probe.snapshot();
    expect(snapshot['count'], 1);
    final Map<Object?, Object?> frame =
        (snapshot['frames']! as List<Object?>).single! as Map<Object?, Object?>;
    expect(frame['buildMs'], 4.0);
    expect(frame['rasterMs'], 5.0);
    expect(frame['vsyncMs'], 1.0);
  });

  test('snapshot reports p95 percentiles', () {
    final FrameProbe probe = FrameProbe.instance;
    probe.reset();
    final int at = pastWarmupAt();
    probe.debugAddTimings(<FrameTiming>[
      FrameTiming(
        vsyncStart: 0,
        buildStart: 0,
        buildFinish: 2000,
        rasterStart: 2000,
        rasterFinish: 4000,
        rasterFinishWallTime: 4000,
      ),
    ], atMs: at);
    final Map<String, Object?> p95 = probe.snapshot()['p95']! as Map<String, Object?>;
    expect(p95['buildMs'], 2.0);
    expect(p95['rasterMs'], 2.0);
    expect(probe.snapshot()['p95Recent'], isA<Map<dynamic, dynamic>>());
    expect(probe.snapshot()['p95Session'], isA<Map<dynamic, dynamic>>());
  });

  test('drops warmup frames from session percentiles', () {
    final FrameProbe probe = FrameProbe.instance;
    probe.reset();
    final int start = DateTime.now().millisecondsSinceEpoch;
    probe.debugSetStartedAtMs(start);

    // Inside warmup window — must not affect p95Session.
    probe.debugAddTimings(<FrameTiming>[
      FrameTiming(
        vsyncStart: 0,
        buildStart: 0,
        buildFinish: 40000,
        rasterStart: 40000,
        rasterFinish: 50000,
        rasterFinishWallTime: 50000,
      ),
    ], atMs: start + 100);

    // After warmup — normal frame.
    probe.debugAddTimings(<FrameTiming>[
      FrameTiming(
        vsyncStart: 0,
        buildStart: 0,
        buildFinish: 2000,
        rasterStart: 2000,
        rasterFinish: 4000,
        rasterFinishWallTime: 4000,
      ),
    ], atMs: start + 4000);

    final Map<String, Object?> snap = probe.snapshot();
    final Map<Object?, Object?> session =
        snap['p95Session']! as Map<Object?, Object?>;
    expect(session['buildMs'], 2.0);
  });

  test('1 Hz idle frames mark jank as inconclusive', () {
    final FrameProbe probe = FrameProbe.instance;
    probe.reset();
    final int start = DateTime.now().millisecondsSinceEpoch - 20000;
    probe.debugSetStartedAtMs(start);

    // Ten frames one second apart — each over budget on totalSpan, but sparse.
    for (var i = 0; i < 10; i++) {
      probe.debugAddTimings(<FrameTiming>[
        FrameTiming(
          vsyncStart: 0,
          buildStart: 0,
          buildFinish: 5000,
          rasterStart: 5000,
          rasterFinish: 30000,
          rasterFinishWallTime: 30000,
        ),
      ], atMs: start + 5000 + i * 1000);
    }

    final Map<String, Object?> snap = probe.snapshot();
    expect(snap['jankInconclusive'], isTrue);
    expect(snap['jankRatio'], 0);
    expect((snap['recentFps'] as num) < 10, isTrue);
  });

  test('dense back-to-back frames make jank conclusive', () {
    final FrameProbe probe = FrameProbe.instance;
    probe.reset();
    final int start = DateTime.now().millisecondsSinceEpoch - 5000;
    probe.debugSetStartedAtMs(start);

    for (var i = 0; i < 30; i++) {
      probe.debugAddTimings(<FrameTiming>[
        FrameTiming(
          vsyncStart: 0,
          buildStart: 0,
          buildFinish: 5000,
          rasterStart: 5000,
          rasterFinish: 30000,
          rasterFinishWallTime: 30000,
        ),
      ], atMs: start + 3500 + i * 16);
    }

    final Map<String, Object?> snap = probe.snapshot();
    expect(snap['jankInconclusive'], isFalse);
    expect((snap['jankRatio'] as num) > 0, isTrue);
  });
}
