# Benchmark reports

Results of the in-game benchmark (Settings → Run benchmark, design §18.4.1), one JSON file per run:
`YYYY-MM-DD_<who>_<gpu>.json`. Paste the report from **Copy results** into a new file here.

Targets (design §19.1): minimum tier 60 FPS average and 1 % low ≥ 45 at Medium quality, 75 % render scale.

Frame times are wall-clock gaps between frames with vsync off during the run (changed 2026-11-03). Reports before that change (such as a 100 FPS run on 2026-11-03 that was not kept) used the engine's smoothed `delta` and ran with vsync, so their FPS is capped by the display and their 1 % low is not meaningful.

Reports from every platform and machine are kept, not replaced: the Windows i7-13620H run (`2026-11-03_adesh_intel-uhd_wallclock.json`) and the Linux i5-10210U runs (`..._i5-10210U-linux*.json`) sit side by side. For a new contributor or machine, add a file named `YYYY-MM-DD_<who>_<cpu-or-gpu>-<os>.json`; add `_run2` and so on for repeats on the same day.
