## 0.2.5

- RebuildProbe no longer inflates `FrameTiming.buildDuration`: the rebuild
  callback only inserts into an identity set; route/id/source work runs in the
  post-frame flush.
- Keep the route-label cache across frames/polls (cap 2000) instead of clearing
  it on every flush/snapshot.
- Cache idle snapshots for 250ms; budget the mounted-tree walk at 5ms once
  inside the target route (`partial: true` when truncated); expose `probeOverheadUs` /
  `probeFlushOverheadUs` / `probeSnapshotOverheadUs`; skip the tree walk when
  the last flush was already expensive.

## 0.2.4

- Cut the profiler's own main-isolate cost (it was inflating the very CPU/stall
  numbers PulseFlow reports): `isUsefulScreenName` no longer compiles a RegExp
  per ancestor, route labels are cached per frame, the mounted-tree walk no
  longer re-resolves the route for every node, and `detectLiveRoute` skips the
  Router walk when a modal route name exists.

## 0.2.3

- Rebuild roots now carry `file:line` — source resolution no longer skips private
  app widgets (only real framework shells and `*Transition`).
- Detect builders that rebuild their reusable `child` (`AnimatedBuilder`,
  `ListenableBuilder`, `ValueListenableBuilder`) via `childProvided` /
  `childReused` on the widget stats.
- Fix `resetWidgetProbe` leaving the probe frozen (a reset now resumes recording).

## 0.2.2

- Remove the `injectInvoices` demo extension/stress action (use the `listFlood`
  scenario and `PulseFlowStressState.invoices` instead).
- README: document the PulseFlow MCP server (`pulseflow-mcp` on npm) so a coding
  agent can read the live session directly.

## 0.2.1

- README: drop insecure `http://` markdown links so pub points stay at 160.

## 0.2.0

- **Device context:** `ext.pulseflow.getDeviceContext` reports platform, build
  mode, locale, text scale, display metrics, and optional app enricher extras.
- **Custom scenarios:** `registerPulseFlowScenario()` merges app scenarios into
  `listScenarios` / `runScenario` (built-in ids cannot be overridden).
- **UI stall probe:** `ext.pulseflow.getStallReport` detects main-isolate
  freezes above a configurable threshold (default 250 ms).
- **Network:** `networkBurst` fires real HTTP GETs by default (or an
  `onNetworkBurst` hook); captured URIs redact auth/token query params.
- `registerPulseFlow` gains `trackStalls`, `stallThreshold`, and
  `deviceEnricher` options.

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
