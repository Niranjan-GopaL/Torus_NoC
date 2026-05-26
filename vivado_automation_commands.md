# Vivado Automation Reference — NoC Torus 4×4

This is a complete reference for running NoC simulation experiments in Vivado
from the command line. Everything you need to reproduce the experiments is in
this folder.

---

## 0. TL;DR — Reproduce all results from a blank slate

```bash
cd /home/nira/Documents/code/swe/claude_code_project/noc_project/final

# 1. Recreate the Vivado project (one-time)
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source create_project.tcl

# 2. Experiment 1: FIFO depth sweep for each routing algorithm
bash switch_routing.sh custom  && bash run_exp1_sweep.sh "Custom"
bash switch_routing.sh xy      && bash run_exp1_sweep.sh "XY"
bash switch_routing.sh oddeven && bash run_exp1_sweep.sh "Odd-Even"
bash switch_routing.sh custom  # restore to baseline

# 3. Experiment 2+: workload variants (see run_exp_workload.sh)
bash run_exp_all.sh

# Results land in: results.md (APPEND-ONLY)
```

---

## 1. Files in this folder

| File | Purpose |
|---|---|
| `router_fifo.sv` | NoC router source (3 routing algorithms inside `xy_route_logic`) |
| `torus_4x4.sv` | 4×4 torus top module; exposes `FIFO_DEPTH` parameter |
| `tb_torus_large.sv` | Sim TB for Experiment 1 (random traffic, 80% BP, prints `CYCLES = N`) |
| `tb_different_workload.sv` | Sim TB for Experiments 2+ (6 traffic patterns, configurable BP, prints latency stats) |
| `create_project.tcl` | Rebuilds the Vivado project from scratch (idempotent) |
| `switch_routing.sh` | Sets active routing algorithm (xy / oddeven / custom) by editing `router_fifo.sv` |
| `switch_workload.sh` | Sets traffic pattern + BP parameters in `tb_different_workload.sv` |
| `run_exp1_sweep.sh` | FIFO depth sweep for whichever algorithm is currently active |
| `run_exp_workload.sh` | One workload-experiment run (single TB config), extracts cycles + latency |
| `run_exp_all.sh` | Master runner for Experiments 2+ (all patterns × all algorithms) |
| `router_fifo.sv.golden` | Auto-created baseline of router_fifo.sv (Custom-active) used by switch_routing |
| `results.md` | Append-only result tables (never overwritten) |
| `vivado_automation_commands.md` | This file |

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
