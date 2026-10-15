import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulseflow_flutter/pulseflow_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    StallProbe.instance.stop();
    StallProbe.instance.reset();
  });

  test('reports recorded stalls', () {
    final StallProbe probe = StallProbe.instance;
    probe.reset();
    probe.debugRecordStall(durationMs: 400, route: '/home');
    probe.debugRecordStall(durationMs: 260, route: '/cart');

    final Map<String, Object?> report = probe.report();
    expect(report['available'], isTrue);
    expect(report['total'], 2);
    expect(report['maxDurationMs'], 400);
    expect(report['detector'], 'frameTiming');
    final List<Object?> stalls = report['stalls']! as List<Object?>;
    expect(stalls, hasLength(2));
    expect((stalls.first! as Map<Object?, Object?>)['route'], '/home');
  });

  test('FrameTiming with large vsyncOverhead counts as a stall', () {
    final StallProbe probe = StallProbe.instance;
    probe.reset();
    probe.start(threshold: const Duration(milliseconds: 250));

    // vsyncOverhead = 300ms, build = 4ms → stall (scheduled frame started late).
    probe.debugAddTimings(<FrameTiming>[
      FrameTiming(
        vsyncStart: 0,
        buildStart: 300000,
        buildFinish: 304000,
        rasterStart: 304000,
        rasterFinish: 310000,
        rasterFinishWallTime: 310000,
      ),
    ]);

    final Map<String, Object?> report = probe.report();
    expect(report['total'], 1);
    expect(report['maxDurationMs'], greaterThanOrEqualTo(250));
    final Map<Object?, Object?> stall =
        (report['stalls']! as List<Object?>).single! as Map<Object?, Object?>;
    expect(stall['kind'], 'vsync');
  });

  test('normal frame under threshold is not a stall', () {
    final StallProbe probe = StallProbe.instance;
    probe.reset();
    probe.start(threshold: const Duration(milliseconds: 250));

    probe.debugAddTimings(<FrameTiming>[
      FrameTiming(
        vsyncStart: 0,
        buildStart: 1000,
        buildFinish: 5000,
        rasterStart: 5000,
        rasterFinish: 12000,
        rasterFinishWallTime: 12000,
      ),
    ]);

    expect(probe.report()['total'], 0);
  });

  test('idle gap without a late FrameTiming does not create stalls', () {
    // The old Timer.periodic detector treated isolate sleep between 1 Hz
    // frames as stalls. FrameTiming-only detection stays quiet until a
    // scheduled frame actually arrives late.
    final StallProbe probe = StallProbe.instance;
    probe.reset();
    probe.start(threshold: const Duration(milliseconds: 250));
    expect(probe.report()['total'], 0);
  });
}
