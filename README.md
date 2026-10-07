# pulseflow_flutter

App-side probes for [PulseFlow](https://github.com/ialirezairanmanesh/PulseFlow).
Registers `ext.pulseflow.*` service extensions and exposes accurate runtime signals
to the dashboard.

## What it adds

- **Accurate frame timings** via `SchedulerBinding.addTimingsCallback` — real build/raster/vsync
  durations, not estimates.
- **Refresh-rate-aware budget** from the active display (`1000 / refreshRate`), so 90/120 Hz
  devices are judged correctly.
- **Widget source locations** (`file:line`) for heavy rebuilds, resolved through the widget
  inspector (debug/profile).
- **HTTP capture** via a delegating `HttpOverrides` — covers `package:http` and Dio's IO adapter
  without the VM Service HTTP profiler.
- **Leak signals** from `FlutterMemoryAllocations` (outstanding created-not-disposed objects).

## Usage

```yaml
dependencies:
  pulseflow_flutter:
    git:
      url: https://github.com/ialirezairanmanesh/pulseflow_flutter.git
```

Local development against a sibling clone:

```yaml
dependencies:
  pulseflow_flutter:
    path: ../pulseflow_flutter
```

```dart
import 'package:pulseflow_flutter/pulseflow_flutter.dart';

void main() {
  registerPulseFlow(appPackage: 'my_app');
  runApp(const MyApp());
}
```

Options: `appPackage`, `captureFrames`, `captureNetwork`, `trackLeaks`, `trackErrors`,
`trackImages`.

## RPCs

| RPC | Purpose |
| --- | --- |
| `getFrameStats` | Accurate frame timings + refresh rate/budget |
| `getRebuildCauses` | Rebuild roots + attributed descendants |
| `getErrors` | Overflow / assertion / exception signatures |
| `getImageStats` | Image cache health + oversized decodes |
| `getNetworkLog` | Drain captured HTTP requests |
| `getLeakReport` | Outstanding objects by class |
| `startWidgetProbe` / `stopWidgetProbe` / `resetWidgetProbe` / `setWidgetProbeFrozen` / `getHotWidgets` | Rebuild probe with source locations |
| `injectInvoices` / `spikeCpu` / `allocateMemory` | Stress actions |
| `listScenarios` / `runScenario` / `stopScenario` | Repeatable lab scenarios |

Notes: the widget probe, source locations, leak signals, and scenarios require debug/profile
builds. HTTP capture works in all modes but adds a thin wrapper around `HttpClient`.

## Layout

```
lib/
  pulseflow_flutter.dart              public API (registerPulseFlow)
  src/rpc/service_extension_registry.dart
  src/probes/…
  src/device/…
  src/scenarios/…
  src/state/stress_state.dart
example/                              minimal app
test/                                 unit tests
```

## Test

```bash
flutter test
flutter analyze
```

## Dashboard + bridge

This package is the app-side half of PulseFlow. The Next.js dashboard and Dart bridge live in
the [PulseFlow](https://github.com/ialirezairanmanesh/PulseFlow) repository.
