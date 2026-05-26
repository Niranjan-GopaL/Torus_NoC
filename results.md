



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
