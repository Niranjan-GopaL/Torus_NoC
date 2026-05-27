# Vivado Automation Reference — NoC Torus 4×4

Complete reference for the simulation pipeline. After the 2026-05-27 reorg the
tree lives under `final/{src,scripts,tcl,docs,claude_stratchpad_workpsace}`.

> **For experimental findings**, jump to `docs/results.md` (the
> [Findings & Analysis](results.md#findings--analysis--2026-05-27) section at
> the end summarises what the 345-sim re-run revealed about routing
> algorithms, FIFO sizing, backpressure, and Odd-Even's performance gap).

---

## 0. TL;DR — Reproduce all results from a blank slate

```bash
cd <path-to>/final          # this repo's root

# 1. (One-time) Recreate the Vivado project. The TCL reads PROJ_NAME and
#    VIVADO_PROJECTS_DIR from the environment — see scripts/_env.sh.
source scripts/_env.sh
"$VIVADO" -mode batch -source "$TCL_DIR/create_project.tcl"

# 2. Run every experiment end-to-end
bash scripts/run_full_rerun.sh
#   ^ Exp1 (FIFO sweep × 3 algos via tb_torus_large.sv)
#     Exp2-5 (workload variants via run_exp_all.sh)
#     Exp6-11 (heavy BP, FIFO=1, heatmap, full matrix, load scaling via run_exp_extras.sh)

# Results: docs/results.md (markdown tables, APPEND-ONLY)
#          docs/results_workload.csv (machine-readable rows)
# Per-sim logs: claude_stratchpad_workpsace/logs/<RUN_TAG>.log
# Per-sim TCL : claude_stratchpad_workpsace/tcl/<RUN_TAG>.tcl
```

Single workload sim, manually:

```bash
bash scripts/switch_routing.sh custom   # custom | xy | oddeven
bash scripts/run_one_workload.sh Custom UNIFORM_RANDOM 70 10 8 60000
#                                ^ALGO  ^PATTERN     ^BP ^HOT ^FIFO ^SIM_NS
# stdout: Custom,UNIFORM_RANDOM,70,10,8,2173,31,4,69
```

---

## 1. The layout

```
final/
├── src/                                  # Design SystemVerilog
│   ├── router_fifo.sv                    #  3 routing algos in xy_route_logic
│   ├── router_fifo.sv.golden             #  Snapshot used by switch_routing.sh
│   ├── torus_4x4.sv                      #  4×4 wrapper, FIFO_DEPTH parameter knob
│   └── tb/                               #  Testbenches
│       ├── tb_torus_large.sv             #   Exp1 TB (prints CYCLES = N)
│       ├── tb_different_workload.sv      #   Exp2+ TB (prints latency stats)
│       └── tb_different_workload.sv.golden
├── scripts/                              # Every .sh — each sources _env.sh
│   ├── _env.sh                           #  Common path config
│   ├── switch_routing.sh / switch_workload.sh
│   ├── run_one_workload.sh
│   ├── run_exp1_sweep.sh                 #  Exp1
│   ├── run_exp_all.sh                    #  Exp2-5
│   ├── run_exp6_heavybp.sh / run_exp7_fifo1.sh
│   ├── run_exp8_2d_heatmap.sh / run_exp9_fifo_heavyload.sh
│   ├── run_exp10_full_matrix.sh / run_exp11_load_scaling.sh
│   ├── run_exp3_rerun.sh                 #  Targeted Exp3 re-runner
│   ├── run_exp_extras.sh                 #  Exp6-11 chain
│   └── run_full_rerun.sh                 #  Exp1-11 master
├── tcl/
│   └── create_project.tcl
├── docs/
│   ├── results.md (append-only)
│   ├── results_workload.csv
│   └── vivado_automation_commands.md     ← this file
└── claude_stratchpad_workpsace/
    ├── session_log.md
    ├── tcl/                              # Generated TCL per sim, keyed by RUN_TAG
    └── logs/                             # XSim log per sim, keyed by RUN_TAG
```

`RUN_TAG = <ALGO>_<PATTERN>_BP<bp>_HOT<hot>_FIFO<d>_SIM<sim>` — every TCL/log
filename in the scratchpad uses this. A row in `results.md` can be cross-
referenced back to the exact TCL that produced it via the RUN_TAG.

---

## 1b. Path configuration — `scripts/_env.sh`

`scripts/_env.sh` is the single source of truth for every path. The shell
scripts source it; the TCL scripts read the same values from the
environment via `$env(NAME)`. Variables are exported so child processes
inherit them.

### Three knobs you might need to change

Edit the USER CONFIG block at the top of `scripts/_env.sh`, or override via
environment variables before invoking any script:

| Variable               | Default                          | Notes                                       |
|------------------------|----------------------------------|---------------------------------------------|
| `VIVADO_PROJECTS_DIR`  | `$HOME/vivado_projects`          | Parent dir where the .xpr is created        |
| `PROJ_NAME`            | `Torus_4x4_extensive_tests`      | Project + .xpr filename                     |
| `VIVADO`               | `/tools/Xilinx/Vivado/2024.2/bin/vivado` | Vivado binary                       |

### Derived (read-only) — do not edit

| Variable      | Resolves to                                          |
|---------------|------------------------------------------------------|
| `ROOT_DIR`    | `<final>`                                            |
| `SRC_DIR`     | `$ROOT_DIR/src`                                      |
| `TB_DIR`      | `$ROOT_DIR/src/tb`                                   |
| `SCRIPTS_DIR` | `$ROOT_DIR/scripts`                                  |
| `TCL_DIR`     | `$ROOT_DIR/tcl`                                      |
| `SCRATCH_DIR` | `$ROOT_DIR/claude_stratchpad_workpsace`              |
| `DOCS_DIR`    | `$ROOT_DIR/docs`                                     |
| `PROJ_DIR`    | `$VIVADO_PROJECTS_DIR/$PROJ_NAME`                    |
| `PROJ_XPR`    | `$PROJ_DIR/$PROJ_NAME.xpr`                           |
| `RESULTS_FILE`| `$DOCS_DIR/results.md`                               |
| `RESULTS_CSV` | `$DOCS_DIR/results_workload.csv`                     |

### Retargeting examples

```bash
# One-off run with a different Vivado install
VIVADO=/opt/Xilinx/Vivado/2023.2/bin/vivado bash scripts/run_full_rerun.sh

# Move the Vivado project out of $HOME
VIVADO_PROJECTS_DIR=/scratch/$USER/vivado bash scripts/run_full_rerun.sh

# Different project name (e.g. for a fork)
PROJ_NAME=MyTorusFork bash scripts/run_full_rerun.sh
```

`tcl/create_project.tcl` reads the same three variables via `env(...)` and
falls back to script-relative defaults if they aren't set, so it also works
when invoked standalone outside the shell pipeline.

---

## 2. Vivado batch-mode fundamentals

### 2.1 The `vivado` command

```bash
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source script.tcl
```

| Flag | Meaning |
|---|---|
| `-mode batch` | Headless. Run the TCL and exit. (`-mode tcl` keeps an interactive prompt; `-mode gui` opens the GUI.) |
| `-source <file>` | Execute this TCL file at startup. |
| `-nolog` / `-nojournal` | Suppress `vivado.log` / `vivado.jou`. **Don't use these when debugging** — you lose error messages. |

### 2.2 Anatomy of a sim-launch TCL

```tcl
open_project /path/to/project.xpr        # Load the project
set_property generic {} [get_filesets sim_1]  # Clear cached parameter overrides
launch_simulation -mode behavioral       # Compile + elaborate + start XSim
run 60000ns                              # Advance simulation 60 microseconds
close_sim                                # Tear down XSim
exit                                     # Quit Vivado
```

Vivado prints `$display` output from the testbench to stdout while `run` is
executing. That is how we extract results: `grep "CYCLES = " log.txt`.

### 2.3 What Vivado writes to disk during a sim

When you `launch_simulation`, Vivado writes into the project folder:

```
<project>/
  Torus_4x4_extensive_tests.sim/   <- compiled snapshot + xsim work area
  Torus_4x4_extensive_tests.cache/ <- IP/compile cache
  .Xil/                            <- transient locks + temp files
```

**To force a fresh compile** (which we need when source files change):

```bash
# SAFE: explicit named directories only
rm -rf "$PROJ_DIR/Torus_4x4_extensive_tests.sim"
rm -rf "$PROJ_DIR/Torus_4x4_extensive_tests.cache"
rm -rf "$PROJ_DIR/.Xil"
```

**Never** use `rm -rf Torus_4x4_extensive_tests.*` — the `.*` glob will match
the `.xpr` project file itself and you'll delete the project.

---

## 3. The parameter chain (critical lesson)

The most painful bug we hit: changing FIFO depth in the source file had no effect.

### Why

```
testbench (tb_torus_4x4_random_bp_10k)
   |
   |  torus_4x4 dut(...);          // NO override -> uses torus_4x4's default
   v
torus_4x4 #(parameter FIFO_DEPTH = 64)        <-- *** this default wins ***
   |
   |  torus_router_5x5 #(.FIFO_DEPTH(FIFO_DEPTH))  // passes value down
   v
torus_router_5x5 #(parameter FIFO_DEPTH = 64)
   |
   |  router_with_fifo #(.FIFO_DEPTH(FIFO_DEPTH))
   v
router_with_fifo -> fifo_sync #(.DEPTH(FIFO_DEPTH))
```

When a parameter is **passed explicitly** down the hierarchy (the `#(.X(X))`
syntax), the value at the call site overrides the default at the leaf. So
editing `torus_router_5x5`'s default at `router_fifo.sv:799` has **no effect** —
`torus_4x4` always passes its own value down.

The only knob that matters is `torus_4x4.sv:22`. That's the line our scripts
target with sed.

### Why TCL generic overrides didn't work either

```tcl
set_property generic {FIFO_DEPTH=2} [get_filesets sim_1]
# -> xelab fails: "Parameter FIFO_DEPTH not found in design"
```

The sim top is `tb_torus_4x4_random_bp_10k`, which has NO `FIFO_DEPTH`
parameter — that's two levels deep inside `dut`. Hierarchical generic paths
(`dut.FIFO_DEPTH=2`) didn't work in our Vivado either, and Vivado *caches* the
generic in the `.xpr` so leftover values poison subsequent runs.

**Lesson:** for parametric sweeps, prefer source edits with sed over TCL
generics, and `set_property generic {}` to clear cached values at the start of
every TCL.

---

## 4. Routing-algorithm switching

The `xy_route_logic` module in `router_fifo.sv` holds three `always_comb`
blocks, only one of which should be uncommented at a time.

| Block | Lines | Comment style when inactive |
|---|---|---|
| XY        | 31–42  | prefix `//    ` (// + 4 spaces) |
| Odd-Even  | 47–93  | prefix `// ` (// + 1 space) |
| Custom    | 99–125 | active in the golden baseline |

`switch_routing.sh` restores from `router_fifo.sv.golden` (created on first
call) and then applies sed transforms:

```bash
# To activate XY
sed -i '31,42 s|^    //    |    |' router_fifo.sv  # Uncomment XY (strip //+4sp)
sed -i '99,125 s|^    |    // |' router_fifo.sv    # Comment Custom (add //+1sp)

# To activate Odd-Even
sed -i '47,93 s|^    // |    |' router_fifo.sv     # Uncomment Odd-Even (strip //+1sp)
sed -i '99,125 s|^    |    // |' router_fifo.sv    # Comment Custom (add //+1sp)
```

The script counts active `always_comb begin` lines inside `xy_route_logic` and
refuses to proceed unless exactly one is active. Use `cat switch_routing.sh`
for the full source.

---

## 5. Result extraction from logs

Each testbench prints summary lines at the end of simulation:

`tb_torus_large.sv` (Experiment 1):
```
CYCLES = 2424
```

`tb_different_workload.sv` (Experiments 2+):
```
Cycles taken    : 4521
Approx latency (cycles, see header caveat):
  average : 42
  min     : 4
  max     : 187
```

To extract a value:
```bash
grep "Cycles taken" log.txt | tail -1 | sed 's/.*: //' | tr -d ' '
grep "  average :"  log.txt | tail -1 | awk '{print $NF}'
```

---

## 6. Gotchas / things to never do

| Don't | Why |
|---|---|
| `rm -rf <proj>.*` | The `.*` glob deletes the `.xpr` project file. Use explicit dir names. |
| Overwrite `results.md` (>, `head`, `tee` w/o `-a`) | Old runs are valuable data. Only use `>>` or `tee -a`. |
| `vivado -nolog -nojournal` while debugging | Hides error messages from Vivado/xelab. |
| Trust the first sed pattern you write | Verify with `grep -c` after; sed silently no-ops on mismatch. |
| Leave `set_property generic {X=Y}` in TCL between runs | Vivado caches it in `.xpr` — clear with `set_property generic {} [get_filesets sim_1]`. |
| Change `router_fifo.sv`'s `torus_router_5x5` default to vary FIFO depth | It's overridden upstream. Change `torus_4x4.sv:22` instead. |

---

## 7. Full reproduction recipe (from a clean machine)

```bash
# 0. Ensure project parent dir exists and is owned by you
sudo chown -R $USER:$USER /home/nira/Documents/code/ece/rtl
mkdir -p /home/nira/Documents/code/ece/rtl

cd /home/nira/Documents/code/swe/claude_code_project/noc_project/final

# 1. Sanity test Vivado runs without sudo
echo 'puts "OK"; exit' > /tmp/smoke.tcl
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source /tmp/smoke.tcl

# 2. Build the project
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source create_project.tcl

# 3. Run experiments. Each script appends to results.md.
bash switch_routing.sh custom  && bash run_exp1_sweep.sh "Custom"
bash switch_routing.sh xy      && bash run_exp1_sweep.sh "XY"
bash switch_routing.sh oddeven && bash run_exp1_sweep.sh "Odd-Even"
bash switch_routing.sh custom  # restore baseline before Exp 2+

bash run_exp_all.sh            # All workload patterns × all algorithms
```

---

# Session Command Log

Chronological log of every command actually run during the session. Use this
when you want to see what was tried, what failed, and what worked. The
"Reference" sections above are the cleaned-up summary; this is the
warts-and-all history.

## 2026-05-26 — Initial setup

```bash
# Confirm Vivado runs without sudo
echo 'puts "VIVADO_OK"; exit' > /tmp/vivado_smoke.tcl
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -nolog -nojournal -source /tmp/vivado_smoke.tcl

# Take ownership of the Vivado project so we don't need sudo for sim
sudo chown -R nira:nira /home/nira/Documents/code/ece/rtl/Torus_4x4_extensive_tests

# Inspect what's in the final folder
ls /home/nira/Documents/code/swe/claude_code_project/noc_project/final
grep -H "^module " /home/nira/Documents/code/swe/claude_code_project/noc_project/final/*.sv
```

## 2026-05-26 — First experiment attempts (the bugs)

```bash
# Attempt 1: TCL hierarchical generic — failed (xelab couldn't find param)
set_property generic {dut.FIFO_DEPTH=2} [get_filesets sim_1]
# ERROR: [XSIM 43-3281] Parameter/Generic dut.FIFO_DEPTH not found in design.

# Attempt 2: edit router_fifo.sv torus_router_5x5 default — failed
# (all 6 sweeps returned CYCLES=2211)
# Cause: torus_4x4 passes its own FIFO_DEPTH down, overriding the leaf default.

# Self-inflicted bug: deleted the .xpr by globbing
rm -rf /home/nira/Documents/code/ece/rtl/Torus_4x4_extensive_tests/Torus_4x4_extensive_tests.*
# ^ this DELETED the .xpr file. Lesson: never glob inside the project directory.
```

## 2026-05-27 — Recovery + correct approach

```bash
# Verify source files are intact
ls -la /home/nira/Documents/code/swe/claude_code_project/noc_project/final/*.sv

# Recreate parent dir if needed
mkdir -p /home/nira/Documents/code/ece/rtl

# Recreate the Vivado project from scratch (see create_project.tcl)
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch \
  -source /home/nira/Documents/code/swe/claude_code_project/noc_project/final/create_project.tcl

# Verify the new project file exists
ls -la /home/nira/Documents/code/ece/rtl/Torus_4x4_extensive_tests/
head -10 /home/nira/Documents/code/ece/rtl/Torus_4x4_extensive_tests/Torus_4x4_extensive_tests.xpr

# Confirm the parameter chain so we sed the RIGHT line
sed -n '22p' torus_4x4.sv
grep -A 1 "torus_4x4 dut" tb_torus_large.sv

# Run the corrected FIFO sweep for Custom routing
bash run_exp1_sweep.sh Custom

# Build switch_routing.sh and verify all three algos
chmod +x switch_routing.sh
bash switch_routing.sh xy
sed -n '8,50p' router_fifo.sv          # visual check XY is uncommented
bash switch_routing.sh oddeven
sed -n '45,95p' router_fifo.sv | head -55
bash switch_routing.sh custom
sed -n '99,105p' router_fifo.sv

# Run Experiment 1 for all three algorithms
bash switch_routing.sh xy      && bash run_exp1_sweep.sh "XY"
bash switch_routing.sh oddeven && bash run_exp1_sweep.sh "Odd-Even"
bash switch_routing.sh custom  # restore baseline

# Verify clean restoration
sed -n '99,105p' router_fifo.sv   # Custom block active
sed -n '22p'    torus_4x4.sv       # FIFO_DEPTH back to 64
tail -60 results.md
```

**Experiment 1 final table** (also in results.md):

| FIFO Depth | Custom | XY | Odd-Even |
|---|---|---|---|
| 2  | 2424 | 2797 | 2797 |
| 4  | 2386 | 2586 | 2586 |
| 8  | **2166** | 2487 | 2487 |
| 16 | 2271 | 2427 | 2427 |
| 32 | 2283 | 2334 | 2334 |
| 64 | 2211 | 2185 | 2185 |

## 2026-05-27 — Experiments 2-5: workload variants

Switched sim top from `tb_torus_4x4_random_bp_10k` (Exp 1) to
`tb_noc_workload_comparison` (Exp 2+). This second testbench supports:

- 6 traffic patterns: `UNIFORM_RANDOM`, `HOTSPOT`, `BIT_COMPLEMENT`,
  `TORNADO`, `MATRIX_TRANSPOSE`, `NEIGHBOR_BURST`
- `BP_READY_PERCENT` — % of cycles the consumer asserts ready (lower = heavier
  backpressure)
- `BP_HOTSPOT_PCT` — % of `HOTSPOT` traffic aimed at node 0
- Reports `Cycles taken` + `average / min / max` latency

### Sim-top switch in TCL (Vivado)

```tcl
open_project {/path/to/project.xpr}
set_property top tb_noc_workload_comparison [get_filesets sim_1]
launch_simulation -mode behavioral
run 60000ns
```

### Workload-parameter switching with sed

`tb_different_workload.sv` exposes three configurable `localparam`s near
line 40. We sed each in place:

```bash
# Pattern
sed -i "s|localparam traffic_pattern_t TRAFFIC_PATTERN = .*;|localparam traffic_pattern_t TRAFFIC_PATTERN = HOTSPOT;|" tb_different_workload.sv

# Backpressure (lower number = heavier backpressure)
sed -i "s|localparam int BP_READY_PERCENT = .*;|localparam int BP_READY_PERCENT = 70;|" tb_different_workload.sv

# Hotspot intensity (only relevant for HOTSPOT pattern)
sed -i "s|localparam int BP_HOTSPOT_PCT   = .*;|localparam int BP_HOTSPOT_PCT   = 30;|" tb_different_workload.sv
```

`switch_workload.sh` wraps all three in one call, restoring from
`tb_different_workload.sv.golden` first.

### Extracting latency stats from the log

`tb_different_workload.sv` prints four interesting numbers per run:

```
=== RESULTS ===
Cycles taken    : 4521
Approx latency (cycles, see header caveat):
  average : 42
  min     : 4
  max     : 187
```

Grep recipe:

```bash
CYCLES=$(grep "Cycles taken" log.txt | tail -1 | sed 's/.*: //' | tr -d ' ')
AVG=$(grep -E "^.*average\s*:" log.txt | tail -1 | awk '{print $NF}')
MIN=$(grep -E "^.*min\s*:" log.txt | tail -1 | awk '{print $NF}')
MAX=$(grep -E "^.*max\s*:" log.txt | tail -1 | awk '{print $NF}')
```

### Experiment matrix (run by `run_exp_all.sh`)

| Exp | Holds fixed | Varies | Total runs |
|---|---|---|---|
| 2 | BP=70%, FIFO=8, BP_HOTSPOT=10% | 6 patterns × 3 algos | 18 |
| 3 | PATTERN=HOTSPOT, BP=70%, FIFO=8 | 5 hotspot pcts × 3 algos | 15 |
| 4 | PATTERN=UNIFORM_RANDOM, FIFO=8 | 5 BP levels × 3 algos | 15 |
| 5 | BP=70%, BP_HOTSPOT=10% | 3 adv. patterns × 3 FIFOs × 3 algos | 27 |

Total: ~75 simulations. Each takes ~30-60s, so the matrix runs in ~45-75 min.

```bash
# Run everything (background-friendly)
bash run_exp_all.sh
```

The script:
- Builds an `# Experiment X: ...` section in `results.md` per experiment
- Also writes raw per-row CSV to `results_workload.csv` for plotting
- Uses `trap` to restore all source files to baseline on exit (clean or
  interrupted)
- Holds the CSV header line: `experiment,algo,pattern,bp_ready,bp_hotspot,fifo,cycles,avg_lat,min_lat,max_lat,timestamp`

---

## 8. The `SIM_NS` parameter (added 2026-05-27)

### 8.1 Why it exists

`tb_different_workload.sv` only emits its `=== RESULTS ===` block after **all
16000 packets drain** (or `MAX_CYCLES` is hit). In the original `run_exp_all.sh`
every sim ran for a fixed `run 60000ns`. For the heaviest patterns (HOTSPOT
with `BP_HOTSPOT_PCT >= 30`, or `BP_READY_PERCENT <= 50`) this was not enough
time to drain the network — the run terminated mid-traffic, no results were
printed, and the metric extractor returned `NA` for every field.

Symptoms in the log when this happens:

```
[5085000] Progress: 1600 / 16000
...
[59025000] Progress: 12800 / 16000     <-- still in flight at 59 µs
# close_sim                              <-- (no === RESULTS === block above)
```

### 8.2 The fix

`run_one_workload.sh` now accepts an optional 6th argument `SIM_NS`:

```bash
bash run_one_workload.sh <ALGO> <PATTERN> <BP_READY> <BP_HOT> <FIFO> [SIM_NS]
#                                                              ^^^^^^^^
#                                                              default = 60000
```

It substitutes into the TCL:

```tcl
run ${SIM_NS}ns
```

### 8.3 How to pick a value

The drain time is bounded by the busiest sink. At `BP_READY_PERCENT = X%`,
one node can absorb `0.X` packets/cycle. With 16000 total packets, in the
worst case all destined for that node:

```
worst_case_cycles  ≈  16000 / (BP_READY_PERCENT / 100)
worst_case_ns      ≈  worst_case_cycles * 4   (clk period = 4ns in TB)
```

Rough guidance:

| Workload character | Recommended `SIM_NS` |
|---|---|
| Light (UNIFORM_RANDOM, BP ≥ 70%, FIFO ≤ 8) | 60000 (default) |
| Moderate (HOTSPOT 10%, BP=70%) | 60000 |
| Heavy (HOTSPOT ≥ 30%, BP=70%) | 400000 |
| Very heavy (BP ≤ 40%, any pattern) | 500000 |
| Adversarial worst case (BP=20% + HOTSPOT≥50%) | 1000000 |

Cost of overshooting is small: the TB calls `$finish` immediately after the
last packet, so extra ns are free wall-time.

---

## 9. Re-running Experiment 3 (the NA fix)

Use `run_exp3_rerun.sh` for the targeted re-run that only touches the rows
HOTSPOT={30,50,70,90}. It uses `SIM_NS=400000` and appends a fresh
`# Experiment 3 (re-run)` table to `results.md` — the original (broken) table
stays in place since `results.md` is append-only.

```bash
cd /home/nira/Documents/code/swe/claude_code_project/noc_project/final
bash run_exp3_rerun.sh
```

The script is self-contained (`set -u`, `trap cleanup EXIT INT TERM`) and
safe to run unattended.

---

## 10. Experiments 6 & 7 — additional sweeps

### Experiment 6: Heavy-backpressure stress (`run_exp6_heavybp.sh`)

| Fixed | Varies |
|---|---|
| FIFO_DEPTH=8, BP_HOTSPOT=10% | PATTERN ∈ {HOTSPOT, MATRIX_TRANSPOSE, BIT_COMPLEMENT}, BP_READY ∈ {20%, 40%}, ALGO ∈ {Custom, XY, Odd-Even} |

18 runs total, SIM_NS=500000 each. Shows how the algorithms behave when the
sink is the bottleneck.

### Experiment 7: Minimum-buffer case (`run_exp7_fifo1.sh`)

| Fixed | Varies |
|---|---|
| FIFO_DEPTH=1, BP_READY=70%, BP_HOTSPOT=10% | 6 patterns × 3 algorithms |

18 runs total, SIM_NS=200000 each. Probes the area-minimum design point —
each router is effectively a pipeline stage with no buffering.

```bash
bash run_exp6_heavybp.sh
bash run_exp7_fifo1.sh
```

---

## 11. Complete reproduction recipe (everything from scratch)

```bash
cd /home/nira/Documents/code/swe/claude_code_project/noc_project/final

# 1. Rebuild the Vivado project
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source create_project.tcl

# 2. Experiment 1 (FIFO sweep, three algos)
bash switch_routing.sh custom  && bash run_exp1_sweep.sh "Custom"
bash switch_routing.sh xy      && bash run_exp1_sweep.sh "XY"
bash switch_routing.sh oddeven && bash run_exp1_sweep.sh "Odd-Even"
bash switch_routing.sh custom

# 3. Experiments 2-5 (workload variants, big matrix)
bash run_exp_all.sh

# 4. Experiment 3 re-run (fixes the NA rows in step 3 — see §8/§9)
bash run_exp3_rerun.sh

# 5. Experiment 6 (heavy BP) and 7 (FIFO=1) — optional but cheap
bash run_exp6_heavybp.sh
bash run_exp7_fifo1.sh
```

Wall-clock budget: ~90-120 minutes for steps 2-5 combined.

All result tables are appended to `results.md`; raw rows go to
`results_workload.csv`. Source files (`router_fifo.sv`, `torus_4x4.sv`,
`tb_different_workload.sv`) are restored to their baselines on every script
exit via the `trap cleanup EXIT INT TERM` pattern.

---

## 12. Session command log — 2026-05-27 (continued)

```bash
# Discover Exp3 NA root cause: open one of the failure logs
tail -60 /tmp/exp_workload_Custom_HOTSPOT_70_30_8.log
# -> "[59025000] Progress: 12800 / 16000" -- sim didn't finish, no === RESULTS ===

# Confirm by checking the TB exit path
grep -n "RESULTS\|finish\|MAX_CYCLES" tb_different_workload.sv.golden
# -> line 326: while (total_recv_count < TOTAL_PKTS && sim_cycles < MAX_CYCLES)
# -> line 373: $display("=== RESULTS ===");   (only after the while loop)

# Patch run_one_workload.sh to accept SIM_NS (6th arg, default 60000)
# Patch run_exp_all.sh: for HOT>=30% pass SIM_NS=400000

# Write a targeted re-run for ONLY the bad Exp3 rows
chmod +x run_exp3_rerun.sh
bash run_exp3_rerun.sh

# Additional experiments
chmod +x run_exp6_heavybp.sh run_exp7_fifo1.sh
bash run_exp6_heavybp.sh
bash run_exp7_fifo1.sh
```
