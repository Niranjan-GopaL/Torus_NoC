# Changelog

## 2026-05-27 — Pre-publication cleanup

- **Centralised path config.** All paths now live in `scripts/_env.sh`. Both
  shell scripts and `tcl/create_project.tcl` read from a single set of
  variables (`VIVADO_PROJECTS_DIR`, `PROJ_NAME`, `VIVADO`). Move the repo
  anywhere and everything still works.
- **Repo layout.** Reorganised into `src/`, `src/tb/`, `scripts/`, `tcl/`,
  `docs/`, `notebooks/`, `claude_stratchpad_workpsace/`. No code logic
  changed, only locations.
- **Renamed** `src/vc_router_outptu_fifos.sv` → `src/vc_router_output_fifos.sv`
  (typo).
- **Removed** the deprecated `scripts/run_exp1_custom.sh` (used the broken
  `set_property generic FIFO_DEPTH=…` approach — superseded by
  `run_exp1_sweep.sh`).
- **`.gitignore`** keeps Vivado runtime cruft and per-sim TCL/logs out of
  git, while explicitly allowlisting 10 representative samples in
  `claude_stratchpad_workpsace/{tcl,logs}/`.

## 2026-05-27 — Odd-Even routing bug fix + full re-run

- **Bug.** The Odd-Even `always_comb` block in `router_fifo.sv` (lines
  47–93) was implementing dimension-order XY in both column-parity
  branches. The result was that every Odd-Even sim across the entire
  prior experiment set produced bit-identical numbers to XY.
- **Fix.** Replaced with the canonical Glass & Ni (1993) deterministic
  odd-even turn model. EN/ES turns forbidden in even columns; NW/SW
  turns forbidden in odd columns. Block kept at exactly 47 lines so the
  hardcoded line ranges in `switch_routing.sh` still work.
- **Validation.** XY = 2447 cycles, fixed Odd-Even = 2475 cycles on
  UNIFORM_RANDOM (BP=70 %, FIFO=8). XY ≠ Odd-Even — the bug is fixed.
- **Re-ran 345 simulations** (Exp1 through Exp11) with the corrected
  Odd-Even. Findings written up at the end of `docs/results.md`.

## Earlier — Bring-up

- Custom torus-aware routing, XY routing, and (broken) Odd-Even routing
  implemented in `router_fifo.sv`.
- Single-router testbenches in `src/tb/` (`tb_router.sv`,
  `tb_router_simple.sv`).
- 4×4 topology testbenches: `tb_torus_directed.sv`, `tb_torus_random.sv`,
  `tb_torus_backpressure.sv`, `tb_torus_large.sv`.
- Workload-comparison testbench `tb_different_workload.sv` with six
  traffic patterns and configurable backpressure.
- Vivado batch-mode automation: `scripts/run_one_workload.sh` +
  `run_exp_all.sh`.
