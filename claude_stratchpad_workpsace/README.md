# claude_stratchpad_workpsace

Working directory for the automation pipeline. Every TCL generated for a
Vivado sim and every captured XSim log lands here, named by the run
parameters so a row in `docs/results.md` can always be traced back to the
exact sim that produced it.

## Layout

```
claude_stratchpad_workpsace/
  README.md          <- this file
  session_log.md     <- chronological, append-only record of automation activity
  scripts/           <- helper Python (build_notebook.py, exec_notebook.py)
  tcl/               <- TCL scripts generated for each Vivado batch sim
  logs/              <- Stdout/stderr captured per simulation
```

## What's tracked in git

Only **10 representative samples** are checked in (see `.gitignore` for the
allowlist) — one per experiment family, spanning Custom / XY / Odd-Even and
the most informative traffic patterns. The full 345-sim trove is regenerated
by running `scripts/run_full_rerun.sh` (~2.5 hours wall-clock).

## File-naming convention

Both `tcl/` and `logs/` use the same tag:

```
<ALGO>_<PATTERN>_BP<bp_ready>_HOT<bp_hotspot>_FIFO<fifo>_SIM<sim_ns>.{tcl,log}
```

Example: `Custom_HOTSPOT_BP70_HOT30_FIFO8_SIM400000.log` is the XSim log for
Custom routing on HOTSPOT pattern with BP_READY=70%, BP_HOTSPOT=30%,
FIFO_DEPTH=8, sim time 400000ns.

## Why not /tmp?

- `/tmp` is wiped on reboot — debugging across days became painful.
- Keeping artifacts inside the project folder makes it easier to
  cross-reference a result row with the underlying log.
- Same-disk write avoids any cross-filesystem latency.

## How to clean up

```bash
rm -rf claude_stratchpad_workpsace/tcl claude_stratchpad_workpsace/logs
```

The scripts recreate `tcl/` and `logs/` on next run via `mkdir -p`.
The `session_log.md` is append-only — keep it.
