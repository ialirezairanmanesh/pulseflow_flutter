## 0.1.0

- Initial release of the PulseFlow app-side package.
- Accurate frame timings via `SchedulerBinding.addTimingsCallback`, with
  refresh-rate-aware budgets from the active display.
- Rebuild hotspot probe with stable widget ids, route labels, and source
  locations (`file:line`) through the widget inspector.
- HTTP capture via a delegating `HttpOverrides`.
- Leak signals from `FlutterMemoryAllocations` (created-not-disposed objects).
- Runtime error / overflow signatures, image cache health, and oversized decode
  tracking.
- Built-in lab scenarios and stress RPCs (`scrollStorm`, `routeThrash`,
  `listFlood`, `animationFlood`, `retainMemory`, `networkBurst`).
- Public entry point: `registerPulseFlow()` registering `ext.pulseflow.*`
  service extensions for the PulseFlow dashboard.
