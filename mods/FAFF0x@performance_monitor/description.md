# Performance Monitor v1.3.0

A diagnostic profiler built to answer: **which mod is hurting game fluidity, and can I export the evidence for analysis?**

## Controls

- **F3** — show/hide overlay.
- **F4** — compact/detailed view.
- **F6** — reset rolling live samples.
- **F8** — start a 10-second deep diagnostic capture. Press again to stop early.
- **F9** — export/re-export the last completed diagnostic.

## Recommended workflow

1. Leave the normal mod set enabled.
2. Go to the exact map/menu/battle where the slowdown happens.
3. Press **F8**.
4. Reproduce the slowdown continuously for 10 seconds.
5. When the diagnostic ends, the report is **exported automatically**.
6. Upload **`performance_report_latest.json`** for analysis.

The monitor also writes a human-readable `performance_report_latest.txt`.

Timestamped copies are archived under:

`performance_reports/performance_report_YYYYMMDD_HHMMSS.json`

## What is inside the JSON report

The export is designed to be machine-readable and contains substantially more data than the overlay:

- Performance Monitor version and report schema version.
- Gen1Recomp engine version and Mod API version.
- Red/Blue/Yellow game version.
- OS, LÖVE version, renderer/GPU information and window/pixel dimensions.
- Relevant game display/speed options.
- Exact list of loaded mods, versions, priorities, dependencies and load order.
- Every measured frame time from the F8 capture.
- Presented FPS, average/median/P95/P99/worst frame time and 1% low FPS.
- Missed 16.67 ms frame-budget count.
- Slow/severe/unattributed frame counts.
- Gen1Recomp logic steps during the capture.
- Per-mod exclusive CPU time, calls, worst callback, draw/canvas/shader work.
- Slow-frame correlation (`STUT`).
- Deep Lua sampler attribution (`DEEP`).
- Direct and deep hotspots.
- Detailed records for every slow frame with state/map, winning attribution,
  top direct contributors, deep contributors and renderer counters.
- A 4 Hz time series for FPS, frame time, Logic/s, Lua memory, texture memory,
  draw calls, state and map.

This makes it possible to compare whether a slowdown is primarily:

- a specific mod's Lua CPU work;
- an occasional callback spike;
- a render-heavy UI/graphics mod;
- a quest/content callback being executed indirectly by another framework;
- a memory/texture growth problem;
- or mostly **UNATTRIBUTED**, suggesting GPU/driver/engine-side work.

## Where the file is saved

The report uses LÖVE's normal Gen1Recomp save directory.

The easiest file to send is always:

`performance_report_latest.json`

After an F8 capture the overlay shows `EXPORT: performance_report_latest.json`, and
the Gen1Recomp log prints the full save-directory path when the platform exposes it.

## Interpreting the main metrics

- **CPU** — exclusive mod hook/event CPU. Time inside `next(...)` is subtracted.
- **STUT** — percentage of slow frames where the mod was the strongest measured contributor.
- **MAX** — worst individual measured callback.
- **D** — exclusive draw calls per second from render hooks.
- **S / DEEP** — Lua instruction samples attributed to the mod during F8.
- **Slow unattrib** — slow frames for which the monitor refuses to invent a culprit.

No user-space mod can perfectly assign GPU driver or C-side engine execution to a
specific Lua mod. The exported report preserves that uncertainty explicitly instead
of manufacturing a false attribution.

## Privacy

The report contains performance data, renderer/device strings, game settings and the
loaded mod list. It does **not** intentionally export save progress, player names,
filesystem mod paths, or the absolute save-directory path inside the JSON.
