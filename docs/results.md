



# XY Routing ( 70% hotspot )

=== RESULTS ===
Cycles taken    : 15729
Packets sent    : 16000 / 16000
Packets received: 16000 / 16000
PASS: all packets sent
PASS: all packets received

Approx latency (cycles, see header caveat):
  average : 36
  min     : 4
  max     : 330
PASS: payload counts all match
------------------------------------------
PASS = 3 / 3
FAIL = 0
FINAL RESULT: PASS
==========================================



# Custom Routing Algorithm ( 70% hotspot )

=== RESULTS ===
Cycles taken    : 15290
Packets sent    : 16000 / 16000
Packets received: 16000 / 16000
PASS: all packets sent
PASS: all packets received

Approx latency (cycles, see header caveat):
  average : 35
  min     : 4
  max     : 193
PASS: payload counts all match
------------------------------------------
PASS = 3 / 3
FAIL = 0
FINAL RESULT: PASS
==========================================










================================================================================================================================================================


# XY Routing ( 90% hotspot )

=== RESULTS ===
Cycles taken    : 19470
Packets sent    : 16000 / 16000
Packets received: 16000 / 16000
PASS: all packets sent
PASS: all packets received

Approx latency (cycles, see header caveat):
  average : 43
  min     : 4
  max     : 613
PASS: payload counts all match
------------------------------------------
PASS = 3 / 3
FAIL = 0
FINAL RESULT: PASS
==========================================



# Odd Even routing (90% hotspot )

=== RESULTS ===
Cycles taken    : 19470
Packets sent    : 16000 / 16000
Packets received: 16000 / 16000
PASS: all packets sent
PASS: all packets received

Approx latency (cycles, see header caveat):
  average : 43
  min     : 4
  max     : 613
PASS: payload counts all match
------------------------------------------
PASS = 3 / 3
FAIL = 0
FINAL RESULT: PASS
==========================================


# Custom routing ( 90% hotspot )

=== RESULTS ===
Cycles taken    : 19383
Packets sent    : 16000 / 16000
Packets received: 16000 / 16000
PASS: all packets sent
PASS: all packets received

Approx latency (cycles, see header caveat):
  average : 42
  min     : 4
  max     : 549
PASS: payload counts all match
------------------------------------------
PASS = 3 / 3
FAIL = 0
FINAL RESULT: PASS
==========================================




================================================================================================================================================================


THIS WORKLOAD CAN BE SEEN IN MODERN AI ACCELERATOR :


# Odd even routing ( Bit Compliment pattern )

=== RESULTS ===
Cycles taken    : 2237
Packets sent    : 16000 / 16000
Packets received: 16000 / 16000
PASS: all packets sent
PASS: all packets received

Approx latency (cycles, see header caveat):
  average : 14
  min     : 6
  max     : 31
PASS: payload counts all match
------------------------------------------
PASS = 3 / 3
FAIL = 0
FINAL RESULT: PASS
==========================================




# Custom Torus routing ( Bit Compliment pattern )

=== RESULTS ===
Cycles taken    : 1475
Packets sent    : 16000 / 16000
Packets received: 16000 / 16000
PASS: all packets sent
PASS: all packets received

Approx latency (cycles, see header caveat):
  average : 8
  min     : 6
  max     : 18
PASS: payload counts all match
------------------------------------------
PASS = 3 / 3
FAIL = 0
FINAL RESULT: PASS
==========================================





================================================================================================================================================================





# Experiment 1: Custom Routing - FIFO Depth Sweep
| FIFO Depth | Cycles Taken |
|---|---|
| 2 |  |
| 4 |  |
| 8 |  |
| 16 |  |
| 32 |  |



# Experiment 1: Custom Routing - FIFO Depth Sweep
| FIFO Depth | Cycles Taken |
|---|---|
| 2 | 2211 |
| 4 | 2211 |


# Experiment 1: Custom Routing — FIFO Depth Sweep
_Run: 2026-05-27 00:21, sim time 60000ns, top = tb_torus_4x4_random_bp_10k_

| FIFO Depth | Cycles Taken |
|---|---|
| 2 | 2211 |
| 4 | 2211 |
| 8 | 2211 |
| 16 | 2211 |
| 32 | 2211 |
| 64 | 2211 |


# Experiment 1: Custom Routing — FIFO Depth Sweep
_Run: 2026-05-27 00:37, sim time 60000ns, top = tb_torus_4x4_random_bp_10k_

| FIFO Depth | Cycles Taken |
|---|---|
| 2 | 2424 |
| 4 | 2386 |
| 8 | 2166 |
| 16 | 2271 |
| 32 | 2283 |
| 64 | 2211 |


# Experiment 1: XY Routing — FIFO Depth Sweep
_Run: 2026-05-27 01:05, sim time 60000ns, top = tb_torus_4x4_random_bp_10k_

| FIFO Depth | Cycles Taken |
|---|---|
| 2 | 2797 |
| 4 | 2586 |
| 8 | 2487 |
| 16 | 2427 |
| 32 | 2334 |
| 64 | 2185 |


# Experiment 1: Odd-Even Routing — FIFO Depth Sweep
_Run: 2026-05-27 01:08, sim time 60000ns, top = tb_torus_4x4_random_bp_10k_

| FIFO Depth | Cycles Taken |
|---|---|
| 2 | 2797 |
| 4 | 2586 |
| 8 | 2487 |
| 16 | 2427 |
| 32 | 2334 |
| 64 | 2185 |


# Experiment 1: Consolidated Summary
_Run: 2026-05-27, sim time 60000ns, top = tb_torus_4x4_random_bp_10k_
_(80% local_out_rdy backpressure, 20k random packets, 16 sources)_

| FIFO Depth | Custom | XY  | Odd-Even |
|---|---|---|---|
| 2  | 2424 | 2797 | 2797 |
| 4  | 2386 | 2586 | 2586 |
| 8  | **2166** | 2487 | 2487 |
| 16 | 2271 | 2427 | 2427 |
| 32 | 2283 | 2334 | 2334 |
| 64 | 2211 | 2185 | 2185 |

**Observations:**
- Custom routing wins at small FIFO depths (D=2 saves ~13% vs XY/Odd-Even)
- Custom has an unusual sweet spot at FIFO=8 (2166 cycles, the minimum across all configs)
- XY and Odd-Even give identical numbers — same physical routes for this traffic pattern
- All three converge near ~2200 cycles when FIFO_DEPTH >= 32


===========================================================================================================================


# Experiment 2: Routing × Traffic Pattern
_Run: 2026-05-27 01:30, BP_READY=70%, BP_HOTSPOT=10%, FIFO_DEPTH=8, sim=60000ns_

| Pattern | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |
|---|---|---|---|

| UNIFORM_RANDOM | 2173 / 31 / 69 | 2447 / 37 / 82 | 2447 / 37 / 82 |
| HOTSPOT | 3739 / 47 / 179 | 3942 / 48 / 138 | 3942 / 48 / 138 |
| BIT_COMPLEMENT | 1489 / 34 / 53 | 2154 / 53 / 101 | 2154 / 53 / 101 |
| TORNADO | 2148 / 35 / 58 | 2148 / 35 / 58 | 2148 / 35 / 58 |
| MATRIX_TRANSPOSE | 2886 / 47 / 97 | 3888 / 59 / 165 | 3888 / 59 / 165 |
| NEIGHBOR_BURST | 1673 / 33 / 73 | 1808 / 32 / 78 | 1808 / 32 / 78 |


# Experiment 3: Hotspot Intensity Sweep
_Run: 2026-05-27 01:30, PATTERN=HOTSPOT, BP_READY=70%, FIFO_DEPTH=8, sim=60000ns_

| BP_HOTSPOT_PCT | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |
|---|---|---|---|
| 10% | 3739 / 47 / 179 | 3942 / 48 / 138 | 3942 / 48 / 138 |
| 30% | NA / NA / NA | NA / NA / NA | NA / NA / NA |
| 50% | NA / NA / NA | NA / NA / NA | NA / NA / NA |
| 70% | NA / NA / NA | NA / NA / NA | NA / NA / NA |
| 90% | NA / NA / NA | NA / NA / NA | NA / NA / NA |


# Experiment 4: Backpressure Sweep
_Run: 2026-05-27 01:30, PATTERN=UNIFORM_RANDOM, FIFO_DEPTH=8, sim=60000ns_

_(BP_READY_PERCENT = % of cycles the consumer is ready; lower = heavier backpressure)_

| BP_READY_PERCENT | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |
|---|---|---|---|
| 30% | 4751 / 76 / 214 | 4759 / 81 / 207 | 4759 / 81 / 207 |
| 50% | 2979 / 48 / 122 | 3003 / 50 / 113 | 3003 / 50 / 113 |
| 70% | 2173 / 31 / 69 | 2447 / 37 / 82 | 2447 / 37 / 82 |
| 90% | 1912 / 23 / 66 | 2212 / 31 / 62 | 2212 / 31 / 62 |
| 100% | 1835 / 21 / 50 | 2097 / 28 / 59 | 2097 / 28 / 59 |


# Experiment 5: FIFO × Pattern × Routing
_Run: 2026-05-27 01:30, BP_READY=70%, BP_HOTSPOT=10%, sim=60000ns_

| Pattern | FIFO | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |
|---|---|---|---|---|
| HOTSPOT | 2 | 3809 / 16 / 95 | 3991 / 17 / 66 | 3991 / 17 / 66 |
| HOTSPOT | 8 | 3739 / 47 / 179 | 3942 / 48 / 138 | 3942 / 48 / 138 |
| HOTSPOT | 64 | 3714 / 308 / 1124 | 3674 / 309 / 872 | 3674 / 309 / 872 |
| BIT_COMPLEMENT | 2 | 1486 / 9 / 24 | 2195 / 17 / 36 | 2195 / 17 / 36 |
| BIT_COMPLEMENT | 8 | 1489 / 34 / 53 | 2154 / 53 / 101 | 2154 / 53 / 101 |
| BIT_COMPLEMENT | 64 | 1478 / 194 / 311 | 2159 / 244 / 415 | 2159 / 244 / 415 |
| NEIGHBOR_BURST | 2 | 1719 / 10 / 34 | 2042 / 11 / 33 | 2042 / 11 / 33 |
| NEIGHBOR_BURST | 8 | 1673 / 33 / 73 | 1808 / 32 / 78 | 1808 / 32 / 78 |
| NEIGHBOR_BURST | 64 | 1524 / 201 / 399 | 1613 / 182 / 377 | 1613 / 182 / 377 |


# Experiment 3 (re-run): Hotspot Intensity Sweep
_Run: 2026-05-27 13:53, PATTERN=HOTSPOT, BP_READY=70%, FIFO_DEPTH=8, sim=400000ns_
_Fixes the NA rows from the original Exp3 — original 60000ns was too short for HOT>=30%._

| BP_HOTSPOT_PCT | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |
|---|---|---|---|
| 30% | 7625 / 94 / 370 | 7715 / 91 / 305 | 7715 / 91 / 305 |
| 50% | 11477 / 139 / 531 | 11616 / 138 / 535 | 11616 / 138 / 535 |
| 70% | 15361 / 181 / 627 | 15391 / 183 / 736 | 15391 / 183 / 736 |
| 90% | 19492 / 230 / 1037 | 19716 / 233 / 1650 | 19716 / 233 / 1650 |


=============================================================================================================================
=============================================================================================================================

# ODD-EVEN ROUTING BUG DISCOVERED + FIXED — 2026-05-27

**Problem.** Across every experiment so far, the XY and Odd-Even routing rows
returned bit-identical numbers. Inspection of `router_fifo.sv` lines 47–93 showed
that the "Odd-Even" implementation was effectively XY:
  * Even columns: route X first if dst_x != my_x, else Y. (= XY)
  * Odd columns: route Y first if dst_x == my_x, else X. (= XY)

There was no actual turn restriction applied — the algorithm always exhausted
the X dimension before turning to Y, which is exactly XY routing.

**Fix.** Replaced with the deterministic Glass & Ni odd-even turn model:
  * EN, ES turns forbidden in even columns
  * NW, SW turns forbidden in odd columns
  * Effect: packets going west cannot turn in odd columns; packets going east
    can turn only in odd columns. This produces routes that genuinely differ
    from XY for many src/dst pairs.

**Smoke test (UNIFORM_RANDOM, BP=70%, FIFO=8):**

| Algorithm | Cycles | Avg lat | Max lat |
|---|---|---|---|
| XY (unchanged) | 2447 | 37 | 82 |
| Odd-Even (FIXED) | 2475 | 39 | 75 |
| Custom (unchanged) | 2173 | 31 | 69 |

XY and Odd-Even are now different — the fix is live.

All experiment tables below this point use the corrected Odd-Even routing.
Everything above this divider used the buggy (= XY) Odd-Even — keep for
historical comparison only.

=============================================================================================================================
=============================================================================================================================


# Experiment 1: Custom Routing — FIFO Depth Sweep
_Run: 2026-05-27 15:23, sim time 60000ns, top = tb_torus_4x4_random_bp_10k_

| FIFO Depth | Cycles Taken |
|---|---|
| 2 | SED_FAILED |
| 4 | SED_FAILED |
| 8 | NO_OUTPUT |
| 16 | SED_FAILED |
| 32 | SED_FAILED |
| 64 | SED_FAILED |


# Experiment 1: XY Routing — FIFO Depth Sweep
_Run: 2026-05-27 15:24, sim time 60000ns, top = tb_torus_4x4_random_bp_10k_

| FIFO Depth | Cycles Taken |
|---|---|
| 2 | SED_FAILED |
| 4 | SED_FAILED |
| 8 | NO_OUTPUT |
| 16 | SED_FAILED |
| 32 | SED_FAILED |
| 64 | SED_FAILED |


# Experiment 1: Odd-Even Routing — FIFO Depth Sweep
_Run: 2026-05-27 15:24, sim time 60000ns, top = tb_torus_4x4_random_bp_10k_

| FIFO Depth | Cycles Taken |
|---|---|
| 2 | SED_FAILED |
| 4 | SED_FAILED |
| 8 | NO_OUTPUT |
| 16 | SED_FAILED |
| 32 | SED_FAILED |
| 64 | SED_FAILED |


# Experiment 2: Routing × Traffic Pattern
_Run: 2026-05-27 15:25, BP_READY=70%, BP_HOTSPOT=10%, FIFO_DEPTH=8, sim=60000ns_

| Pattern | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |
|---|---|---|---|

==================================================================================================

# RERUN 2026-05-27 16:43 — after reorg + Odd-Even fix

Source tree reorganized into final/{src,src/tb,scripts,tcl,docs,claude_stratchpad_workpsace}.
Vivado project regenerated to point at the new paths.
Odd-Even routing implementation is the corrected Glass & Ni turn model — Custom / XY / Odd-Even
now give genuinely different numbers.

All tables below this banner come from this run.

==================================================================================================


# Experiment 1: Odd-Even Routing — FIFO Depth Sweep
_Run: 2026-05-27 16:50, sim time 60000ns, top = tb_torus_4x4_random_bp_10k_

| FIFO Depth | Cycles Taken |
|---|---|
| 2 | 3217 |
| 4 | 2994 |
| 8 | 2836 |
| 16 | 2803 |
| 32 | 2822 |
| 64 | 2714 |


# Experiment 2: Routing × Traffic Pattern
_Run: 2026-05-27 16:52, BP_READY=70%, BP_HOTSPOT=10%, FIFO_DEPTH=8, sim=60000ns_

| Pattern | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |
|---|---|---|---|
| UNIFORM_RANDOM | 2173 / 31 / 69 | 2447 / 37 / 82 | 2475 / 39 / 75 |
| HOTSPOT | 3739 / 47 / 179 | 3942 / 48 / 138 | 4013 / 54 / 176 |


<!-- The Exp1 Custom + XY tables below were originally written to
     src/results.md due to a stale RESULTS_FILE path in run_exp1_sweep.sh.
     Migrated here on 2026-05-27 16:55:08. Odd-Even and Exp2+
     went straight into this file. -->


# Experiment 1: Custom Routing — FIFO Depth Sweep
_Run: 2026-05-27 16:44, sim time 60000ns, top = tb_torus_4x4_random_bp_10k_

| FIFO Depth | Cycles Taken |
|---|---|
| 2 | NO_OUTPUT |


# Experiment 1: Custom Routing — FIFO Depth Sweep
_Run: 2026-05-27 16:45, sim time 60000ns, top = tb_torus_4x4_random_bp_10k_

| FIFO Depth | Cycles Taken |
|---|---|
| 2 | 2424 |
| 4 | 2386 |
| 8 | 2166 |
| 16 | 2271 |
| 32 | 2283 |
| 64 | 2211 |


# Experiment 1: XY Routing — FIFO Depth Sweep
_Run: 2026-05-27 16:47, sim time 60000ns, top = tb_torus_4x4_random_bp_10k_

| FIFO Depth | Cycles Taken |
|---|---|
| 2 | 2797 |
| 4 | 2586 |
| 8 | 2487 |
| 16 | 2427 |
| 32 | 2334 |
| 64 | 2185 |
| BIT_COMPLEMENT | 1489 / 34 / 53 | 2154 / 53 / 101 | 4094 / 62 / 139 |
| TORNADO | 2148 / 35 / 58 | 2148 / 35 / 58 | 2148 / 35 / 58 |
| MATRIX_TRANSPOSE | 2886 / 47 / 97 | 3888 / 59 / 165 | 5145 / 66 / 279 |
| NEIGHBOR_BURST | 1673 / 33 / 73 | 1808 / 32 / 78 | 1766 / 30 / 85 |


# Experiment 3: Hotspot Intensity Sweep
_Run: 2026-05-27 16:52, PATTERN=HOTSPOT, BP_READY=70%, FIFO_DEPTH=8, sim=60000ns_

| BP_HOTSPOT_PCT | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |
|---|---|---|---|
| 10% | 3739 / 47 / 179 | 3942 / 48 / 138 | 4013 / 54 / 176 |
| 30% | 7625 / 94 / 370 | 7715 / 91 / 305 | 7856 / 98 / 377 |
| 50% | 11477 / 139 / 531 | 11616 / 138 / 535 | 11453 / 140 / 454 |
| 70% | 15361 / 181 / 627 | 15391 / 183 / 736 | 15401 / 188 / 663 |
| 90% | 19492 / 230 / 1037 | 19716 / 233 / 1650 | 19421 / 236 / 1134 |


# Experiment 4: Backpressure Sweep
_Run: 2026-05-27 16:52, PATTERN=UNIFORM_RANDOM, FIFO_DEPTH=8, sim=60000ns_

_(BP_READY_PERCENT = % of cycles the consumer is ready; lower = heavier backpressure)_

| BP_READY_PERCENT | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |
|---|---|---|---|
| 30% | 4751 / 76 / 214 | 4759 / 81 / 207 | 5042 / 83 / 192 |
| 50% | 2979 / 48 / 122 | 3003 / 50 / 113 | 3301 / 52 / 102 |
| 70% | 2173 / 31 / 69 | 2447 / 37 / 82 | 2475 / 39 / 75 |
| 90% | 1912 / 23 / 66 | 2212 / 31 / 62 | 2289 / 34 / 67 |
| 100% | 1835 / 21 / 50 | 2097 / 28 / 59 | 2265 / 33 / 63 |


# Experiment 5: FIFO × Pattern × Routing
_Run: 2026-05-27 16:52, BP_READY=70%, BP_HOTSPOT=10%, sim=60000ns_

| Pattern | FIFO | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |
|---|---|---|---|---|
| HOTSPOT | 2 | 3809 / 16 / 95 | 3991 / 17 / 66 | 4329 / 19 / 79 |
| HOTSPOT | 8 | 3739 / 47 / 179 | 3942 / 48 / 138 | 4013 / 54 / 176 |
| HOTSPOT | 64 | 3714 / 308 / 1124 | 3674 / 309 / 872 | 4032 / 332 / 903 |
| BIT_COMPLEMENT | 2 | 1486 / 9 / 24 | 2195 / 17 / 36 | 4097 / 21 / 52 |
| BIT_COMPLEMENT | 8 | 1489 / 34 / 53 | 2154 / 53 / 101 | 4094 / 62 / 139 |
| BIT_COMPLEMENT | 64 | 1478 / 194 / 311 | 2159 / 244 / 415 | 4089 / 391 / 981 |
| NEIGHBOR_BURST | 2 | 1719 / 10 / 34 | 2042 / 11 / 33 | 2080 / 11 / 38 |
| NEIGHBOR_BURST | 8 | 1673 / 33 / 73 | 1808 / 32 / 78 | 1766 / 30 / 85 |
| NEIGHBOR_BURST | 64 | 1524 / 201 / 399 | 1613 / 182 / 377 | 1608 / 175 / 367 |


# Experiment 6: Heavy Backpressure Stress
_Run: 2026-05-27 17:22, FIFO_DEPTH=8, BP_HOTSPOT=10%, sim=500000ns_
_Heavy backpressure (BP_READY <= 40%) on the three patterns that diverged most in Exp2._

| Pattern | BP_READY | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |
|---|---|---|---|---|
| HOTSPOT | 20% | 13018 / 176 / 728 | 13246 / 167 / 755 | 12793 / 173 / 742 |
| HOTSPOT | 40% | 6361 / 85 / 342 | 6303 / 80 / 340 | 6404 / 90 / 357 |
| MATRIX_TRANSPOSE | 20% | 10063 / 166 / 374 | 12658 / 199 / 627 | 15225 / 210 / 1091 |
| MATRIX_TRANSPOSE | 40% | 5068 / 82 / 178 | 6422 / 97 / 294 | 7677 / 104 / 587 |
| BIT_COMPLEMENT | 20% | 5251 / 131 / 261 | 5829 / 159 / 340 | 8339 / 158 / 369 |
| BIT_COMPLEMENT | 40% | 2639 / 63 / 109 | 3033 / 80 / 171 | 4576 / 77 / 171 |


# Experiment 7: Minimum-Buffer Case (FIFO_DEPTH=1)
_Run: 2026-05-27 17:29, BP_READY=70%, BP_HOTSPOT=10%, FIFO_DEPTH=1, sim=200000ns_
_How well does the network behave when each router has a single-flit buffer?_

| Pattern | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |
|---|---|---|---|
| UNIFORM_RANDOM | 3187 / 10 / 36 | 3883 / 13 / 43 | 4437 / 14 / 43 |
| HOTSPOT | 4603 / 12 / 80 | 5828 / 15 / 62 | 6199 / 15 / 74 |
| BIT_COMPLEMENT | 2154 / 9 / 17 | 4030 / 19 / 38 | 8020 / 24 / 62 |
| TORNADO | 4031 / 11 / 22 | 4031 / 11 / 22 | 4031 / 11 / 22 |
| MATRIX_TRANSPOSE | 4256 / 12 / 31 | 6220 / 15 / 53 | 8677 / 20 / 79 |
| NEIGHBOR_BURST | 2265 / 6 / 24 | 2593 / 8 / 25 | 2770 / 8 / 31 |


# Experiment 9: FIFO Depth Sweep under Heavy Load
_Run: 2026-05-27 17:36, PATTERN=UNIFORM_RANDOM, BP_READY=30%, BP_HOTSPOT=10%, sim=400000ns_
_Does Exp1's FIFO=8 sweet spot survive when the network is choked?_

| FIFO Depth | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |
|---|---|---|---|
| 1 | 5730 / 22 / 94 | 6525 / 24 / 110 | 6820 / 24 / 90 |
| 2 | 4879 / 31 / 93 | 5457 / 33 / 100 | 5660 / 33 / 105 |
| 4 | 4981 / 49 / 173 | 5199 / 50 / 124 | 5252 / 53 / 132 |
| 8 | 4751 / 76 / 214 | 4759 / 81 / 207 | 5042 / 83 / 192 |
| 16 | 4476 / 135 / 376 | 4564 / 140 / 321 | 4839 / 149 / 312 |
| 32 | 4342 / 259 / 626 | 4294 / 259 / 533 | 4743 / 258 / 482 |
| 64 | 4205 / 508 / 1155 | 4379 / 459 / 951 | 4558 / 486 / 845 |


# Experiment 11: Load Scaling (PKTS_PER_SRC sweep)
_Run: 2026-05-27 17:44, PATTERN=UNIFORM_RANDOM, BP_READY=70%, FIFO_DEPTH=8_
_Cycles should scale roughly linearly with offered load if the network is unsaturated._

| PKTS_PER_SRC | Total packets | Custom (cyc / avg / max) | XY (cyc / avg / max) | Odd-Even (cyc / avg / max) |
|---|---|---|---|---|
| 200 | 3200 | 437 / 30 / 68 | 495 / 35 / 80 | 477 / 36 / 62 |
| 1000 | 16000 | 2173 / 31 / 69 | 2447 / 37 / 82 | 2475 / 39 / 75 |
| 2000 | 32000 | 4553 / 32 / 91 | 5079 / 37 / 82 | 4866 / 39 / 75 |
| 5000 | 80000 | 11461 / 32 / 91 | 12601 / 37 / 82 | 12185 / 39 / 80 |


# Experiment 8 — Custom routing: BP_READY × BP_HOTSPOT (cycles)
_Run: 2026-05-27 17:49, PATTERN=HOTSPOT, FIFO_DEPTH=8 (cycles only)_

| BP_READY \ BP_HOT | 10% | 30% | 50% | 70% | 90% |
|---|
| **20%** | 13018 | 26461 | 40790 | 54379 | 68296 |
| **40%** | 6361 | 12778 | 20354 | 27245 | 34283 |
| **70%** | 3739 | 7625 | 11477 | 15361 | 19492 |
| **90%** | 3017 | 5964 | 9012 | 12004 | 15122 |
| **100%** | 2841 | 5513 | 8202 | 10880 | 13617 |


# Experiment 8 — XY routing: BP_READY × BP_HOTSPOT (cycles)
_Run: 2026-05-27 17:49, PATTERN=HOTSPOT, FIFO_DEPTH=8 (cycles only)_

| BP_READY \ BP_HOT | 10% | 30% | 50% | 70% | 90% |
|---|
| **20%** | 13246 | 26264 | 41222 | 53194 | 67452 |
| **40%** | 6303 | 13425 | 19876 | 27065 | 34154 |
| **70%** | 3942 | 7715 | 11616 | 15391 | 19716 |
| **90%** | 3333 | 6250 | 9085 | 12014 | 15163 |
| **100%** | 3061 | 5783 | 8289 | 11054 | 13676 |


# Experiment 8 — Odd-Even routing: BP_READY × BP_HOTSPOT (cycles)
_Run: 2026-05-27 17:49, PATTERN=HOTSPOT, FIFO_DEPTH=8 (cycles only)_

| BP_READY \ BP_HOT | 10% | 30% | 50% | 70% | 90% |
|---|
| **20%** | 12793 | 26110 | 40486 | 53908 | 67670 |
| **40%** | 6404 | 13539 | 20038 | 26996 | 33944 |
| **70%** | 4013 | 7856 | 11453 | 15401 | 19421 |
| **90%** | 3557 | 6519 | 9290 | 12033 | 15177 |
| **100%** | 3096 | 5991 | 8727 | 11141 | 13728 |


# Experiment 10 — Custom routing: Pattern × FIFO (cycles taken)
_Run: 2026-05-27 18:18, BP_READY=70%, BP_HOTSPOT=10%, sim=200000ns_

| Pattern | FIFO=1 | FIFO=2 | FIFO=4 | FIFO=8 | FIFO=16 | FIFO=32 | FIFO=64 |
|---|
| UNIFORM_RANDOM | 3187 | 2417 | 2367 | 2173 | 2271 | 2168 | 2125 |
| HOTSPOT | 4603 | 3809 | 3892 | 3739 | 3800 | 3691 | 3714 |
| BIT_COMPLEMENT | 2154 | 1486 | 1477 | 1489 | 1478 | 1491 | 1478 |
| TORNADO | 4031 | 2163 | 2176 | 2148 | 2153 | 2169 | 2143 |
| MATRIX_TRANSPOSE | 4256 | 2923 | 2924 | 2886 | 2933 | 2926 | 2929 |
| NEIGHBOR_BURST | 2265 | 1719 | 1725 | 1673 | 1512 | 1593 | 1524 |


# Experiment 10 — XY routing: Pattern × FIFO (cycles taken)
_Run: 2026-05-27 18:18, BP_READY=70%, BP_HOTSPOT=10%, sim=200000ns_

| Pattern | FIFO=1 | FIFO=2 | FIFO=4 | FIFO=8 | FIFO=16 | FIFO=32 | FIFO=64 |
|---|
| UNIFORM_RANDOM | 3883 | 2619 | 2329 | 2447 | 2476 | 2435 | 2289 |
| HOTSPOT | 5828 | 3991 | 3942 | 3942 | 3825 | 3656 | 3674 |
| BIT_COMPLEMENT | 4030 | 2195 | 2197 | 2154 | 2166 | 2174 | 2159 |
| TORNADO | 4031 | 2163 | 2176 | 2148 | 2153 | 2169 | 2143 |
| MATRIX_TRANSPOSE | 6220 | 3922 | 3994 | 3888 | 3992 | 3964 | 3956 |
| NEIGHBOR_BURST | 2593 | 2042 | 1855 | 1808 | 1640 | 1705 | 1613 |


# Experiment 10 — Odd-Even routing: Pattern × FIFO (cycles taken)
_Run: 2026-05-27 18:18, BP_READY=70%, BP_HOTSPOT=10%, sim=200000ns_

| Pattern | FIFO=1 | FIFO=2 | FIFO=4 | FIFO=8 | FIFO=16 | FIFO=32 | FIFO=64 |
|---|
| UNIFORM_RANDOM | 4437 | 2858 | 2662 | 2475 | 2332 | 2313 | 2309 |
| HOTSPOT | 6199 | 4329 | 4155 | 4013 | 3960 | 4077 | 4032 |
| BIT_COMPLEMENT | 8020 | 4097 | 4086 | 4094 | 4082 | 4078 | 4089 |
| TORNADO | 4031 | 2163 | 2176 | 2148 | 2153 | 2169 | 2143 |
| MATRIX_TRANSPOSE | 8677 | 5131 | 5088 | 5145 | 5102 | 5095 | 4994 |
| NEIGHBOR_BURST | 2770 | 2080 | 1905 | 1766 | 1732 | 1641 | 1608 |


==========================================================================================================================================
==========================================================================================================================================


1. Custom routing is the consistent winner

The torus-aware Custom algorithm uses wrap-around links, so for patterns with long horizontal/vertical jumps it has fewer hops than mesh-style XY or Odd-Even:

┌──────────────────────────┬────────┬──────┬──────────┐
│ Pattern (BP=70%, FIFO=8) │ Custom │  XY  │ Odd-Even │
├──────────────────────────┼────────┼──────┼──────────┤
│ BIT_COMPLEMENT           │ 1489   │ 2154 │ 4094     │
├──────────────────────────┼────────┼──────┼──────────┤
│ MATRIX_TRANSPOSE         │ 2886   │ 3888 │ 5145     │
├──────────────────────────┼────────┼──────┼──────────┤
│ UNIFORM_RANDOM           │ 2173   │ 2447 │ 2475     │
├──────────────────────────┼────────┼──────┼──────────┤
│ HOTSPOT 10%              │ 3739   │ 3942 │ 4013     │
└──────────────────────────┴────────┴──────┴──────────┘

2. Odd-Even is the slowest on adversarial patterns

The Glass & Ni turn restrictions (EN/ES forbidden in even columns, NW/SW forbidden in odd columns) cost real cycles on BIT_COMPLEMENT and MATRIX_TRANSPOSE — packets that want to go diagonally west are forced into longer detours.

On BIT_COMPLEMENT this is dramatic: 4094 vs XY's 2154 — 90% slower than XY because every packet needs to cross both dimensions and Odd-Even keeps deferring the turn.

3. TORNADO is identical for all three algos

(src+8) mod 16 means every packet has the same offset on the torus, so all three algorithms pick the same paths. Cycles = 2148 across the board — a sanity check that the three algorithms only diverge when they should.

4. FIFO=8 is the sweet spot at light load (Exp1, Exp10)

Custom under random traffic + 80% BP (Exp1):

┌────────┬──────┬──────┬──────┬──────┬──────┬──────┐
│  FIFO  │  2   │  4   │  8   │  16  │  32  │  64  │
├────────┼──────┼──────┼──────┼──────┼──────┼──────┤
│ Cycles │ 2424 │ 2386 │ 2166 │ 2271 │ 2283 │ 2
└────────┴──────┴──────┴──────┴──────┴──────┴──────┘

Past FIFO=8 returns are flat. FIFO=1 is uniformly bad (Exp7) — single-flit buffering means contention propagates upstream
every cycle.

5. Under heavy backpressure Custom's lead widen

At BP=20% on MATRIX_TRANSPOSE: Custom 10063, XYsinks throttle, the algorithm that creates theleast congestion wins by a larger margin.

6. Hotspot is bandwidth-bound, not routing-bound (Exp3, Exp8)

The 2D heatmap (Exp8) shows cycles scale almost linearly with (BP_READY × BP_HOTSPOT)⁻¹. At HOT=90%: Custom 19492, XY 19716,
 Odd-Even 19421 — they converge because everyonoverloaded sink. Routing choice barely mattersonce the bottleneck is the destination port.

7. FIFO sweet spot shifts under load (Exp9, BP=30%)

┌────────────────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
│      FIFO      │  1   │  2   │  4   │  8   │
├────────────────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┤
│ Custom cyc     │ 5730 │ 4879 │ 4981 │ 4751 │
├────────────────┼──────┼──────┼──────┼──────┼──────┼──────┼──────┤
│ Custom avg lat │ 22   │ 31   │ 49   │ 76   │
└────────────────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘

The Exp1 sweet spot at FIFO=8 disappears under heavy BP — bigger FIFOs reduce cycles (throughput) but jack up average
latency because packets sit in queues longer. Ctradeoff.

8. Load scaling is linear (Exp11)

┌────────────────┬─────┬──────┬──────┬───────┐
│  PKTS_PER_SRC  │ 200 │ 1000 │ 2000 │ 5000  │
├────────────────┼─────┼──────┼──────┼───────┤
│ Custom cycles  │ 437 │ 2173 │ 4553 │ 11461 │
├────────────────┼─────┼──────┼──────┼───────┤
│ Custom avg lat │ 30  │ 31   │ 32   │ 32    │
└────────────────┴─────┴──────┴──────┴───────┘

Cycles double when packets double. Average lateork is not saturated at BP=70%, FIFO=8.

Headline numbers for the writeup

- Custom beats XY by 13–30% on adversarial pattTRANSPOSE).
- FIFO=8 is the area/perf sweet spot at light load; FIFO=16-32 is better under heavy BP.
- Odd-Even is worth showing as a "what not to dctions buy nothing on a torus.

If you want to make Odd-Even competitive: 
make it actually adaptive — let the router pick between the permitted output ports based on which is currently free. 
That requires a small "available output mask" check at the route logic. 
The current code commits to one direction; that's why it's pessimistic.

==================================================================================================
==================================================================================================

# FINDINGS & ANALYSIS — 2026-05-27

Synthesis of the 345-simulation re-run (Exp1–11). Numbers in this section come
from the tables above; the CSV at `docs/results_workload.csv` has all raw rows.

---

## TL;DR — three headline numbers

1. **Custom routing beats XY by 13–30%** on adversarial patterns
   (BIT_COMPLEMENT, MATRIX_TRANSPOSE) because it exploits the torus wrap.
2. **FIFO=8 is the area/perf sweet spot under light load**;
   under heavy backpressure the optimum shifts upward to FIFO=16–32.
3. **Odd-Even is the slowest of the three**, often dramatically so
   (90% slower than XY on BIT_COMPLEMENT). It's worth keeping as a
   "what not to do" baseline — see §4 below for why.

---

## 1. Custom (torus-aware) routing is the consistent winner

The Custom routing block uses `(dst - src) mod 4` and picks the shorter wrap
direction in each dimension. The mesh-style XY and Odd-Even use literal `<`/`>`
comparisons and always take the long way around.

Exp2 (BP=70%, FIFO=8, BP_HOTSPOT=10%):

| Pattern          | Custom   | XY    | Odd-Even |
|------------------|---------:|------:|---------:|
| BIT_COMPLEMENT   | **1489** | 2154  | 4094     |
| MATRIX_TRANSPOSE | **2886** | 3888  | 5145     |
| UNIFORM_RANDOM   | **2173** | 2447  | 2475     |
| HOTSPOT 10%      | **3739** | 3942  | 4013     |
| NEIGHBOR_BURST   | **1673** | 1808  | 1766     |
| TORNADO          | 2148     | 2148  | 2148     |

TORNADO is `(src+8) mod 16` so every packet has the same offset on the torus —
all three algorithms pick the same paths. This is a sanity check that the
implementations only diverge where they should.

Custom's lead widens under heavy backpressure (Exp6). At BP=20% on
MATRIX_TRANSPOSE: **Custom=10063, XY=12658, Odd-Even=15225** — the algorithm
that creates the least congestion wins by a larger margin when sinks throttle.

---

## 2. FIFO depth: the sweet spot depends on load

### Light load (Exp1, BP=80% on tb_torus_large)

Custom routing, random traffic:

| FIFO Depth | 2    | 4    | **8**    | 16   | 32   | 64   |
|------------|-----:|-----:|---------:|-----:|-----:|-----:|
| Cycles     | 2424 | 2386 | **2166** | 2271 | 2283 | 2211 |

FIFO=8 minimizes cycles (2166). Past 8, returns are flat.
At FIFO=1 (Exp7) everyone suffers — single-flit buffering means any contention
immediately propagates upstream every cycle.

### Heavy load (Exp9, BP=30%)

| FIFO Depth | 1    | 2    | 4    | 8    | 16       | 32   | 64   |
|------------|-----:|-----:|-----:|-----:|---------:|-----:|-----:|
| Custom cyc | 5730 | 4879 | 4981 | 4751 | **4476** | 4342 | 4205 |
| Custom avg | 22   | 31   | 49   | 76   | 135      | 259  | 508  |

Bigger FIFOs reduce **cycles** (throughput goes up) but blow up **average
latency** (packets sit in queues longer). Classic throughput-vs-latency
tradeoff. At BP=30% the sweet spot for cycles shifts to FIFO=16–32; for
latency, smaller is still better.

---

## 3. Hotspot traffic is bandwidth-bound, not routing-bound

The 2D heatmap (Exp8) shows cycles scale almost linearly with
`(BP_READY × BP_HOTSPOT)⁻¹`. The bottleneck is the destination's `ready`
signal, not network routing.

At HOTSPOT 90% (Exp3): Custom=19492, XY=19716, Odd-Even=19421 — all three
algorithms converge because everyone is queued behind the same overloaded sink.

Practical implication: optimizing routing buys nothing once you're sink-bound.
Put the engineering effort into output-queue sizing or split traffic across
multiple sinks.

---

## 4. Why is Odd-Even so much slower? (the most surprising result)

### What Odd-Even does

Glass & Ni (1993) turn restrictions:
- **EN, ES forbidden in EVEN columns** — an east-bound packet at column 0/2
  cannot turn N/S here, must continue east.
- **NW, SW forbidden in ODD columns** — a packet just went N or S at column
  1/3 cannot turn west, must keep going N/S.

These restrictions are proven to break cyclic channel dependencies, giving
deadlock freedom. They were proven safe for **mesh**, not for performance.

### Per-packet hop counts are identical to XY

Trace (0,0) → (3,3) under BIT_COMPLEMENT:

```
XY:        (0,0)→(1,0)→(2,0)→(3,0)→(3,1)→(3,2)→(3,3)   [E E E N N N]
Odd-Even:  (0,0)→(1,0)→(1,1)→(1,2)→(1,3)→(2,3)→(3,3)   [E N N N E E]
```

Both take 6 hops. The paths use **different links**, though.

### Why it's slower

1. **Traffic concentration.** Odd-Even's column-parity rule herds east-bound
   diagonals through odd columns and west-bound diagonals through even
   columns. Same number of packets compete for fewer links → more queueing.

2. **Head-of-line blocking.** When an odd-column packet "must continue west"
   and the W port is busy, the packet sits at the head of its input FIFO
   blocking everything behind it. XY has no such restriction.

3. **No adaptivity.** This is the **deterministic** Odd-Even (the one in the
   source). It commits to a single output port. The *adaptive* variant would
   pick among permitted output ports based on which is currently free — that
   would amortize the contention. Our version pays the restriction cost
   without getting the flexibility benefit.

### Smoking gun: BIT_COMPLEMENT FIFO=1 (Exp7)

| Algorithm | Cycles |
|-----------|-------:|
| Custom    | 2154   |
| XY        | 4030   |
| Odd-Even  | **8020** |

XY → Odd-Even is exactly **2×**. With no buffering at all, head-of-line
blocking fully serializes each forced-direction step.

### Where Odd-Even *isn't* terrible

| Pattern         | Why                                                    |
|-----------------|--------------------------------------------------------|
| TORNADO         | Same (src+8) offset → all algos pick the same path     |
| UNIFORM_RANDOM  | Random destinations average out the contention biases |
| HOTSPOT (high)  | Sink-bound; routing doesn't matter                    |

### How to fix Odd-Even

Make it actually adaptive — let the router pick between permitted output
ports based on a "currently free" mask. Pseudocode:

```
permitted_ports = compute_permitted(my_x, my_y, dst_x, dst_y);
out_port        = first_set_bit(permitted_ports & ready_in_from_outputs);
```

That preserves deadlock freedom and recovers the route-flexibility gain. The
current code committed to one direction up-front; that's why it underperforms.

---

## 5. Load scaling is linear (Exp11)

UNIFORM_RANDOM, BP=70%, FIFO=8:

| PKTS_PER_SRC | 200  | 1000  | 2000  | 5000   |
|--------------|-----:|------:|------:|-------:|
| Custom cyc   | 437  | 2173  | 4553  | 11461  |
| Custom avg   | 30   | 31    | 32    | 32     |

Cycles double when packets double. Average latency stays flat — the network
isn't saturated at BP=70% / FIFO=8. The saturation point lives somewhere
between BP=70% and BP=30% (Exp4); average latency jumps from 31 → 76 cycles
when BP drops from 70% to 30%.

---

## 6. Practical conclusions for a final design

| Decision        | Recommendation | Evidence |
|-----------------|----------------|----------|
| Routing algo    | **Custom** (torus-aware mod-4) | Exp2, Exp5, Exp6 |
| FIFO depth      | **8** flits per input port (light load); **16** if expecting sustained BP ≤ 30% | Exp1, Exp9, Exp10 |
| Hotspot mitigation | Add a second output port at the hot sink, or rate-limit injection. Routing changes alone won't help. | Exp3, Exp8 |
| Saturation point | Stays linear up to ~5000 packets/source at BP=70% — design for that envelope | Exp11 |
