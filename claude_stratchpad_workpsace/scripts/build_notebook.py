#!/usr/bin/env python3
"""
Build notebooks/report_plots.ipynb from the per-cell content defined below.
Run from anywhere:  python3 build_notebook.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]          # final/
OUT_NB = ROOT / "notebooks" / "report_plots.ipynb"

# Each entry is (cell_type, source_string). Markdown cells use cell_type "md".
CELLS = []

# -----------------------------------------------------------------------------
# Title + setup
# -----------------------------------------------------------------------------
CELLS.append(("md", r"""# Torus 4×4 NoC — Experimental Report Plots

**Author.** *Niranjan Gopal* — AMD Internship Project
**Date.** May 2026
**Data.** 345 simulations across 11 experiments (`docs/results_workload.csv`).

This notebook reproduces every plot in the project report from the raw
simulation CSV. The story we tell, in five plots:

| Section | Plot | What it shows |
|---|---|---|
| §1 | FIFO depth sweep | The sweet-spot question |
| §2 | Routing × traffic pattern | Custom dominates on adversarial patterns |
| §3 | Backpressure + Hotspot 2D heatmap | Hotspot is bandwidth-bound, not routing-bound |
| §4 | Heavy backpressure stress | Custom's lead widens under stress |
| §5 | FIFO=1 head-of-line | The smoking gun for Odd-Even's slowdown |
| §6 | FIFO under heavy load | Throughput–latency tradeoff |
| §7 | Pattern × FIFO matrix | All 18 algo/pattern combos in one view |
| §8 | Load scaling | The network is unsaturated up to 80k packets |

All figures are saved to `notebooks/figures/` at 300 dpi for report inclusion."""))

# -----------------------------------------------------------------------------
# Imports + style
# -----------------------------------------------------------------------------
CELLS.append(("code", r"""# Setup: imports, plotting style, palette
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mtick
from pathlib import Path

# Locate the project root from this notebook's location
ROOT = Path.cwd()
if ROOT.name == "notebooks":
    ROOT = ROOT.parent
CSV  = ROOT / "docs" / "results_workload.csv"
FIGS = ROOT / "notebooks" / "figures"
FIGS.mkdir(parents=True, exist_ok=True)

# Publication-quality matplotlib style
plt.rcParams.update({
    "figure.dpi":         110,
    "savefig.dpi":        300,
    "savefig.bbox":       "tight",
    "savefig.pad_inches": 0.15,

    "font.family":        "sans-serif",
    "font.sans-serif":    ["Helvetica", "Arial", "DejaVu Sans"],
    "font.size":          11,
    "axes.titlesize":     13,
    "axes.titleweight":   "bold",
    "axes.labelsize":     11,
    "axes.labelweight":   "regular",
    "legend.fontsize":    10,
    "xtick.labelsize":    10,
    "ytick.labelsize":    10,

    "axes.spines.top":    False,
    "axes.spines.right":  False,
    "axes.grid":          True,
    "grid.alpha":         0.25,
    "grid.linestyle":     "--",
    "grid.linewidth":     0.6,
})

# A consistent three-colour palette for the routing algorithms — readable on
# slides and projectors, distinguishable for colour-blind viewers.
COLOR = {
    "Custom":   "#1f77b4",   # blue   — the winner
    "XY":       "#ff7f0e",   # orange — baseline
    "Odd-Even": "#7b1fa2",   # purple — the surprise
}
ALGOS = ["Custom", "XY", "Odd-Even"]

print(f"Project root : {ROOT}")
print(f"CSV          : {CSV}")
print(f"Figures dir  : {FIGS}")
"""))

# -----------------------------------------------------------------------------
# Data load + dedupe
# -----------------------------------------------------------------------------
CELLS.append(("code", r"""# Load CSV and deduplicate
# The CSV was append-only across multiple runs (Odd-Even had a bug in the
# first run). Keep only the LAST occurrence of every (experiment, algo,
# pattern, bp_ready, bp_hotspot, fifo) tuple — that's the corrected data.

df = pd.read_csv(CSV)

# Coerce numeric columns (NA strings -> NaN)
for c in ["cycles", "avg_lat", "min_lat", "max_lat"]:
    df[c] = pd.to_numeric(df[c], errors="coerce")

key_cols = ["experiment", "algo", "pattern", "bp_ready", "bp_hotspot", "fifo"]
df = df.drop_duplicates(subset=key_cols, keep="last").reset_index(drop=True)

print(f"Total rows after dedupe : {len(df)}")
print(f"Experiments present    : {sorted(df['experiment'].unique())}")
df.head()
"""))

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------
CELLS.append(("code", r"""# Small plotting helpers
def style_ax(ax, title=None, xlabel=None, ylabel=None):
    if title:  ax.set_title(title, pad=12)
    if xlabel: ax.set_xlabel(xlabel)
    if ylabel: ax.set_ylabel(ylabel)
    ax.tick_params(direction="out", length=4, width=0.8)
    for s in ("left", "bottom"):
        ax.spines[s].set_linewidth(0.8)

def annotate_winner(ax, x, y, text, dx=0, dy=10):
    '''Draw a small label next to a notable data point.'''
    ax.annotate(
        text, xy=(x, y), xytext=(x + dx, y + dy),
        fontsize=9, ha="center",
        arrowprops=dict(arrowstyle="->", lw=0.6, color="0.3"),
    )

def save(fig, name):
    out = FIGS / f"{name}.png"
    fig.savefig(out)
    print(f"  saved -> {out.name}")
"""))

# -----------------------------------------------------------------------------
# §1 FIFO depth sweep (Exp1) — values hardcoded from results.md
# -----------------------------------------------------------------------------
CELLS.append(("md", r"""## §1. FIFO Depth Sweep — Where's the sweet spot?

Experiment 1 used `tb_torus_large.sv` (80 % uniform-random backpressure) and
swept `FIFO_DEPTH ∈ {2, 4, 8, 16, 32, 64}` for each of the three routing
algorithms. Only `CYCLES` was extracted, no latency statistics.

Source: `docs/results.md`, "Experiment 1" tables (latest rerun, 2026-05-27)."""))

CELLS.append(("code", r"""# Exp1 — FIFO depth sweep (hardcoded because the CSV doesn't include it)
fifo_depths = [2, 4, 8, 16, 32, 64]
exp1 = {
    "Custom":   [2424, 2386, 2166, 2271, 2283, 2211],
    "XY":       [2797, 2586, 2487, 2427, 2334, 2185],
    "Odd-Even": [3217, 2994, 2836, 2803, 2822, 2714],
}

fig, ax = plt.subplots(figsize=(7.5, 4.6))
for algo in ALGOS:
    ax.plot(fifo_depths, exp1[algo], marker="o", markersize=7, lw=2.0,
            color=COLOR[algo], label=algo)

# Annotate Custom's sweet spot
sweet_x, sweet_y = 8, exp1["Custom"][2]
ax.scatter([sweet_x], [sweet_y], s=160, facecolors="none",
           edgecolors=COLOR["Custom"], lw=2, zorder=5)
ax.annotate(f"sweet spot\n{sweet_y} cycles",
            xy=(sweet_x, sweet_y), xytext=(sweet_x + 8, sweet_y - 280),
            fontsize=10, ha="center", color=COLOR["Custom"],
            arrowprops=dict(arrowstyle="->", lw=0.8, color=COLOR["Custom"]))

ax.set_xscale("log", base=2)
ax.set_xticks(fifo_depths)
ax.get_xaxis().set_major_formatter(mtick.ScalarFormatter())
style_ax(ax, title="Experiment 1 — FIFO depth vs. simulation cycles",
         xlabel="FIFO depth (flits)", ylabel="Cycles to drain workload")
ax.legend(frameon=False, loc="upper right")
save(fig, "exp1_fifo_sweep")
plt.show()
"""))

# -----------------------------------------------------------------------------
# §2 Routing × pattern (Exp2)
# -----------------------------------------------------------------------------
CELLS.append(("md", r"""## §2. Routing × Traffic Pattern — Custom wins on adversarial workloads

For each of six canonical traffic patterns at `BP_READY=70%`,
`BP_HOTSPOT=10%`, `FIFO_DEPTH=8`, compare cycles across the three routing
algorithms. *TORNADO* is identical across algorithms because every packet has
the same offset on the torus — useful as a sanity check."""))

CELLS.append(("code", r"""# Exp2 — grouped bars: pattern × algorithm
exp2 = df[df["experiment"] == "Exp2"].copy()

patterns = ["UNIFORM_RANDOM", "HOTSPOT", "BIT_COMPLEMENT", "TORNADO",
            "MATRIX_TRANSPOSE", "NEIGHBOR_BURST"]
x = np.arange(len(patterns))
width = 0.26

fig, ax = plt.subplots(figsize=(11, 5.2))
for i, algo in enumerate(ALGOS):
    sub = exp2[exp2["algo"] == algo].set_index("pattern").loc[patterns]
    ax.bar(x + (i - 1) * width, sub["cycles"], width=width,
           color=COLOR[algo], label=algo,
           edgecolor="white", linewidth=0.5)

# Highlight the most surprising data point: BIT_COMPLEMENT Odd-Even
bc_idx = patterns.index("BIT_COMPLEMENT")
oe_val = exp2[(exp2["algo"] == "Odd-Even") &
              (exp2["pattern"] == "BIT_COMPLEMENT")]["cycles"].iloc[0]
ax.annotate("Odd-Even ≈ 2× XY here\n(see §5)",
            xy=(bc_idx + width, oe_val),
            xytext=(bc_idx + 0.8, oe_val + 900),
            fontsize=10, color="#7b1fa2", ha="left",
            arrowprops=dict(arrowstyle="->", lw=0.8, color="#7b1fa2"))
ax.set_ylim(top=ax.get_ylim()[1] * 1.1)

ax.set_xticks(x)
ax.set_xticklabels(patterns, rotation=18, ha="right")
style_ax(ax, title="Experiment 2 — Cycles by routing algorithm and traffic pattern\n"
              "(BP_READY=70 %, BP_HOTSPOT=10 %, FIFO_DEPTH=8)",
         xlabel="", ylabel="Cycles")
ax.legend(frameon=False, loc="upper left")
save(fig, "exp2_routing_x_pattern")
plt.show()
"""))

# -----------------------------------------------------------------------------
# §3 Hotspot intensity sweep (Exp3)
# -----------------------------------------------------------------------------
CELLS.append(("md", r"""## §3. Hotspot Intensity — bandwidth-bound, not routing-bound

As the percentage of traffic concentrated on node 0 climbs from 10 % to 90 %,
all three algorithms converge — the bottleneck is the destination's `ready`
signal, not the network. Routing decisions stop mattering once the sink is
saturated."""))

CELLS.append(("code", r"""# Exp3 (use Exp3-rerun, which used the longer SIM_NS)
e3 = df[df["experiment"].isin(["Exp3", "Exp3-rerun"])].copy()
e3 = e3.drop_duplicates(subset=["algo", "bp_hotspot"], keep="last")
hot_levels = [10, 30, 50, 70, 90]

fig, ax = plt.subplots(figsize=(7.5, 4.6))
for algo in ALGOS:
    sub = e3[e3["algo"] == algo].set_index("bp_hotspot").loc[hot_levels]
    ax.plot(hot_levels, sub["cycles"], marker="o", markersize=7, lw=2.0,
            color=COLOR[algo], label=algo)

ax.annotate("algorithms converge —\nsink-bound regime",
            xy=(90, e3.cycles.max()), xytext=(55, 14500),
            fontsize=10, ha="center",
            arrowprops=dict(arrowstyle="->", lw=0.8, color="0.4"))

ax.xaxis.set_major_formatter(mtick.PercentFormatter(decimals=0))
style_ax(ax, title="Experiment 3 — Hotspot intensity sweep "
              "(BP_READY=70 %, FIFO_DEPTH=8)",
         xlabel="Hotspot percentage (% of traffic to node 0)",
         ylabel="Cycles to drain workload")
ax.legend(frameon=False, loc="lower right")
save(fig, "exp3_hotspot_sweep")
plt.show()
"""))

# -----------------------------------------------------------------------------
# §4 Backpressure sweep (Exp4)
# -----------------------------------------------------------------------------
CELLS.append(("md", r"""## §4. Backpressure Sweep — saturation is between BP=50 % and 70 %

Lower `BP_READY` = consumer accepts fewer cycles = heavier backpressure. The
inverse relationship is sharp — cycles roughly double from BP=70 % to BP=30 %.
The knee around BP=50–70 % marks the saturation point of this network at
PKTS_PER_SRC=1000, FIFO=8."""))

CELLS.append(("code", r"""# Exp4 — backpressure sweep
e4 = df[df["experiment"] == "Exp4"].copy()
bp_levels = sorted(e4["bp_ready"].unique())

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 4.6))

for algo in ALGOS:
    sub = e4[e4["algo"] == algo].set_index("bp_ready").loc[bp_levels]
    ax1.plot(bp_levels, sub["cycles"], marker="o", markersize=7, lw=2.0,
             color=COLOR[algo], label=algo)
    ax2.plot(bp_levels, sub["avg_lat"], marker="s", markersize=7, lw=2.0,
             color=COLOR[algo], label=algo)

for ax in (ax1, ax2):
    ax.set_xticks(bp_levels)
    ax.xaxis.set_major_formatter(mtick.PercentFormatter(decimals=0))

style_ax(ax1, title="Cycles vs. backpressure",
         xlabel="BP_READY_PERCENT", ylabel="Cycles")
style_ax(ax2, title="Average latency vs. backpressure",
         xlabel="BP_READY_PERCENT", ylabel="Avg packet latency (cycles)")
ax1.legend(frameon=False, loc="upper right")
fig.suptitle("Experiment 4 — Backpressure sweep "
             "(UNIFORM_RANDOM, FIFO_DEPTH=8)", y=1.02, fontsize=13,
             fontweight="bold")
save(fig, "exp4_backpressure")
plt.show()
"""))

# -----------------------------------------------------------------------------
# §5 Heavy BP stress (Exp6)
# -----------------------------------------------------------------------------
CELLS.append(("md", r"""## §5. Heavy Backpressure Stress — Custom's lead widens

At BP=20 %, the consumer accepts only 1 cycle in 5. Routing decisions matter
more, not less, because contention has nowhere to go. On MATRIX_TRANSPOSE,
Custom finishes 50 % faster than Odd-Even."""))

CELLS.append(("code", r"""# Exp6 — heavy backpressure stress
e6 = df[df["experiment"] == "Exp6"].copy()
e6_patterns = ["MATRIX_TRANSPOSE", "BIT_COMPLEMENT", "HOTSPOT"]
e6_bp = [20, 40]

fig, axes = plt.subplots(1, 3, figsize=(14, 4.6), sharey=True)
x = np.arange(len(e6_bp))
width = 0.26

for ax, pat in zip(axes, e6_patterns):
    for i, algo in enumerate(ALGOS):
        sub = e6[(e6["algo"] == algo) & (e6["pattern"] == pat)]
        sub = sub.set_index("bp_ready").loc[e6_bp]
        ax.bar(x + (i - 1) * width, sub["cycles"], width=width,
               color=COLOR[algo], label=algo, edgecolor="white", linewidth=0.5)
    ax.set_xticks(x)
    ax.set_xticklabels([f"BP={bp}%" for bp in e6_bp])
    style_ax(ax, title=pat)
    ax.set_xlabel("")

axes[0].set_ylabel("Cycles")
axes[-1].legend(frameon=False, loc="upper right")
fig.suptitle("Experiment 6 — Heavy backpressure stress "
             "(FIFO_DEPTH=8, BP_HOTSPOT=10 %)", y=1.02, fontsize=13,
             fontweight="bold")
save(fig, "exp6_heavy_bp")
plt.show()
"""))

# -----------------------------------------------------------------------------
# §6 FIFO=1 smoking gun (Exp7)
# -----------------------------------------------------------------------------
CELLS.append(("md", r"""## §6. FIFO=1 Head-of-Line Blocking — the Odd-Even smoking gun

With single-flit input buffers, any contention propagates upstream every
cycle. This is where Odd-Even's turn restrictions become *catastrophic* on
BIT_COMPLEMENT: each forced-direction step fully serialises behind the head
packet. Odd-Even ends up at exactly **2×** XY's cycle count."""))

CELLS.append(("code", r"""# Exp7 — minimum-buffer case (FIFO=1)
e7 = df[df["experiment"] == "Exp7"].copy()
e7_patterns = ["UNIFORM_RANDOM", "HOTSPOT", "BIT_COMPLEMENT",
               "TORNADO", "MATRIX_TRANSPOSE", "NEIGHBOR_BURST"]
x = np.arange(len(e7_patterns))
width = 0.26

fig, ax = plt.subplots(figsize=(11, 5.2))
for i, algo in enumerate(ALGOS):
    sub = e7[e7["algo"] == algo].set_index("pattern").loc[e7_patterns]
    ax.bar(x + (i - 1) * width, sub["cycles"], width=width,
           color=COLOR[algo], label=algo, edgecolor="white", linewidth=0.5)

# Highlight BIT_COMPLEMENT 2× ratio
bc_idx = e7_patterns.index("BIT_COMPLEMENT")
xy_v = e7[(e7["algo"]=="XY") & (e7["pattern"]=="BIT_COMPLEMENT")]["cycles"].iloc[0]
oe_v = e7[(e7["algo"]=="Odd-Even") & (e7["pattern"]=="BIT_COMPLEMENT")]["cycles"].iloc[0]
ratio = oe_v / xy_v
ax.annotate(f"Odd-Even / XY = {ratio:.2f}×\n(head-of-line blocking)",
            xy=(bc_idx + width, oe_v),
            xytext=(bc_idx + 1.0, oe_v + 500),
            fontsize=10, color="#7b1fa2", ha="left",
            arrowprops=dict(arrowstyle="->", lw=0.8, color="#7b1fa2"))
ax.set_ylim(top=ax.get_ylim()[1] * 1.12)   # headroom for the annotation

ax.set_xticks(x)
ax.set_xticklabels(e7_patterns, rotation=18, ha="right")
style_ax(ax, title="Experiment 7 — Minimum buffer (FIFO_DEPTH=1) "
              "exposes Odd-Even's contention cost",
         xlabel="", ylabel="Cycles")
ax.legend(frameon=False, loc="upper left")
save(fig, "exp7_fifo1_headofline")
plt.show()
"""))

# -----------------------------------------------------------------------------
# §7 2D heatmap (Exp8)
# -----------------------------------------------------------------------------
CELLS.append(("md", r"""## §7. 2D Operating-Point Heatmap (BP × Hotspot)

Three heatmaps, one per routing algorithm. Same colour scale across all three
so cells are directly comparable. Cells get redder as the workload gets
harder. The three maps are *nearly identical* on the bottom-right quadrant
(high BP, high hotspot) — the regime where routing stops mattering."""))

CELLS.append(("code", r"""# Exp8 — three 2D heatmaps
e8 = df[df["experiment"] == "Exp8"].copy()
bp_levels  = sorted(e8["bp_ready"].unique(),   reverse=True)   # 100 -> 20
hot_levels = sorted(e8["bp_hotspot"].unique())                 # 10  -> 90

# Build one matrix per algorithm
mats = {}
for algo in ALGOS:
    m = (e8[e8["algo"] == algo]
            .pivot(index="bp_ready", columns="bp_hotspot", values="cycles")
            .reindex(index=bp_levels, columns=hot_levels))
    mats[algo] = m

vmin = min(m.values.min() for m in mats.values())
vmax = max(m.values.max() for m in mats.values())

fig, axes = plt.subplots(1, 3, figsize=(15, 5.2), sharey=True)
for ax, algo in zip(axes, ALGOS):
    m = mats[algo]
    im = ax.imshow(m.values, aspect="auto", cmap="YlOrRd",
                   vmin=vmin, vmax=vmax)
    ax.set_xticks(range(len(hot_levels)))
    ax.set_xticklabels([f"{h}%" for h in hot_levels])
    ax.set_yticks(range(len(bp_levels)))
    ax.set_yticklabels([f"{b}%" for b in bp_levels])
    style_ax(ax, title=f"{algo}", xlabel="BP_HOTSPOT_PCT")
    ax.grid(False)
    # Annotate each cell with the cycle count
    for i in range(m.shape[0]):
        for j in range(m.shape[1]):
            val = int(m.values[i, j])
            txt_color = "white" if val > (vmin + vmax) / 2 else "black"
            ax.text(j, i, f"{val:,}", ha="center", va="center",
                    fontsize=8, color=txt_color)

axes[0].set_ylabel("BP_READY_PERCENT")

# Single shared colorbar
cbar_ax = fig.add_axes([0.92, 0.15, 0.015, 0.7])
cb = fig.colorbar(im, cax=cbar_ax)
cb.set_label("Cycles", rotation=90, labelpad=10)

fig.suptitle("Experiment 8 — Operating-point heatmap "
             "(HOTSPOT, FIFO_DEPTH=8)", y=1.0, fontsize=13, fontweight="bold")
fig.tight_layout(rect=[0, 0, 0.9, 0.96])
save(fig, "exp8_2d_heatmap")
plt.show()
"""))

# -----------------------------------------------------------------------------
# §8 FIFO under heavy load (Exp9)
# -----------------------------------------------------------------------------
CELLS.append(("md", r"""## §8. FIFO Under Heavy Load — the throughput-latency tradeoff

Deeper FIFOs *reduce* cycles (more buffering smooths bursts) but *blow up*
average latency (packets sit longer in queues). Under heavy backpressure
(BP=30 %) the cycle-minimum shifts upward from FIFO=8 (light load, Exp1)
to about FIFO=16–32 — but you pay 2–3× the average latency for those
extra cycles."""))

CELLS.append(("code", r"""# Exp9 — twin-axis: cycles & avg_lat vs FIFO depth (Custom only for clarity)
e9 = df[df["experiment"] == "Exp9"].copy()
fifos = sorted(e9["fifo"].unique())

fig, ax1 = plt.subplots(figsize=(8, 4.8))
ax2 = ax1.twinx()
ax2.grid(False)

algo = "Custom"
sub = e9[e9["algo"] == algo].set_index("fifo").loc[fifos]

l1, = ax1.plot(fifos, sub["cycles"], marker="o", markersize=7, lw=2.0,
               color=COLOR[algo], label=f"{algo} cycles")
l2, = ax2.plot(fifos, sub["avg_lat"], marker="s", markersize=7, lw=2.0,
               color="#d62728", linestyle="--", label=f"{algo} avg latency")

ax1.set_xscale("log", base=2)
ax1.set_xticks(fifos)
ax1.get_xaxis().set_major_formatter(mtick.ScalarFormatter())

style_ax(ax1, title="Experiment 9 — Throughput vs. latency under heavy BP "
                    "(BP_READY=30 %, Custom routing)",
         xlabel="FIFO depth", ylabel="Cycles")
ax2.set_ylabel("Average packet latency (cycles)", color="#d62728")
ax2.tick_params(axis="y", labelcolor="#d62728")
ax2.spines["right"].set_visible(True)
ax2.spines["right"].set_color("#d62728")

ax1.legend(handles=[l1, l2], frameon=False, loc="upper left")
save(fig, "exp9_throughput_latency_tradeoff")
plt.show()
"""))

# -----------------------------------------------------------------------------
# §9 Pattern × FIFO full matrix (Exp10)
# -----------------------------------------------------------------------------
CELLS.append(("md", r"""## §9. Pattern × FIFO Matrix — all 18 algo/pattern lines

Small multiples: one panel per traffic pattern, three curves per panel. This
is the densest plot in the report — useful as an appendix figure showing
that Custom's win generalises across every pattern and every FIFO depth."""))

CELLS.append(("code", r"""# Exp10 — pattern × FIFO matrix (small multiples)
e10 = df[df["experiment"] == "Exp10"].copy()
patterns = ["UNIFORM_RANDOM", "HOTSPOT", "BIT_COMPLEMENT",
            "TORNADO", "MATRIX_TRANSPOSE", "NEIGHBOR_BURST"]
fifos = sorted(e10["fifo"].unique())

fig, axes = plt.subplots(2, 3, figsize=(14, 7.2), sharex=True)
axes = axes.flatten()

for ax, pat in zip(axes, patterns):
    for algo in ALGOS:
        sub = (e10[(e10["algo"] == algo) & (e10["pattern"] == pat)]
                  .set_index("fifo").loc[fifos])
        ax.plot(fifos, sub["cycles"], marker="o", markersize=5, lw=1.6,
                color=COLOR[algo], label=algo)
    ax.set_xscale("log", base=2)
    ax.set_xticks(fifos)
    ax.get_xaxis().set_major_formatter(mtick.ScalarFormatter())
    style_ax(ax, title=pat, xlabel="FIFO depth", ylabel="Cycles")

# Single legend at the figure level
axes[0].legend(frameon=False, loc="upper right")
fig.suptitle("Experiment 10 — Cycles by traffic pattern, FIFO depth and "
             "routing algorithm (BP_READY=70 %, BP_HOTSPOT=10 %)",
             y=1.01, fontsize=13, fontweight="bold")
fig.tight_layout()
save(fig, "exp10_pattern_x_fifo_matrix")
plt.show()
"""))

# -----------------------------------------------------------------------------
# §10 Load scaling (Exp11)
# -----------------------------------------------------------------------------
CELLS.append(("md", r"""## §10. Load Scaling — linear up to 80 k packets

Cycle count scales linearly with `PKTS_PER_SRC` (offered load). Average
latency stays flat (~30 cycles), so the network is comfortably below its
saturation point at BP=70 % / FIFO=8. The design envelope holds at least up
to 80 000 packets."""))

CELLS.append(("code", r"""# Exp11 — load scaling
e11_keys = [k for k in df["experiment"].unique() if k.startswith("Exp11")]
e11 = df[df["experiment"].isin(e11_keys)].copy()
e11["pkts_per_src"] = e11["experiment"].str.extract(r"Exp11-pkts(\d+)").astype(int)
e11 = e11.sort_values("pkts_per_src")
pkts = sorted(e11["pkts_per_src"].unique())

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 4.6))
for algo in ALGOS:
    sub = e11[e11["algo"] == algo].set_index("pkts_per_src").loc[pkts]
    ax1.plot(pkts, sub["cycles"], marker="o", markersize=7, lw=2.0,
             color=COLOR[algo], label=algo)
    ax2.plot(pkts, sub["avg_lat"], marker="s", markersize=7, lw=2.0,
             color=COLOR[algo], label=algo)

# Linear-extrapolation guide on the cycles plot
ax1.plot(pkts, np.array(pkts) * (e11[e11["algo"]=="Custom"]["cycles"].iloc[1] / 1000),
         linestyle=":", color="0.5", lw=1, label="linear-scaling guide")

style_ax(ax1, title="Cycles vs. offered load",
         xlabel="PKTS_PER_SRC", ylabel="Cycles")
style_ax(ax2, title="Average latency is FLAT — network unsaturated",
         xlabel="PKTS_PER_SRC", ylabel="Avg latency (cycles)")
ax1.legend(frameon=False, loc="upper left")
fig.suptitle("Experiment 11 — Load scaling "
             "(UNIFORM_RANDOM, BP_READY=70 %, FIFO_DEPTH=8)",
             y=1.02, fontsize=13, fontweight="bold")
save(fig, "exp11_load_scaling")
plt.show()
"""))

# -----------------------------------------------------------------------------
# §11 Money-shot cover plot
# -----------------------------------------------------------------------------
CELLS.append(("md", r"""## §11. Cover Figure — one slide that summarises the project

A single figure for the report cover or the executive-summary slide. Two
panels: (left) cycles ranking across all six traffic patterns at the
canonical operating point; (right) the four headline numbers as a clean
bar chart."""))

CELLS.append(("code", r"""# Money-shot summary figure
fig, (axL, axR) = plt.subplots(1, 2, figsize=(14, 5),
                                gridspec_kw={"width_ratios": [1.55, 1]})

# ---- Left: Exp2 grouped bars (most informative single view) ----
patterns = ["BIT_COMPLEMENT", "MATRIX_TRANSPOSE", "UNIFORM_RANDOM",
            "NEIGHBOR_BURST", "HOTSPOT", "TORNADO"]
x = np.arange(len(patterns))
width = 0.26
for i, algo in enumerate(ALGOS):
    sub = exp2[exp2["algo"] == algo].set_index("pattern").loc[patterns]
    axL.bar(x + (i - 1) * width, sub["cycles"], width=width,
            color=COLOR[algo], label=algo, edgecolor="white", linewidth=0.5)
axL.set_xticks(x)
axL.set_xticklabels(patterns, rotation=18, ha="right")
style_ax(axL, title="Cycles to drain 16 000 packets, by traffic pattern",
         ylabel="Cycles")
axL.legend(frameon=False, loc="upper right")

# ---- Right: headline-number bar chart ----
# Custom-vs-XY speed-up at three notable operating points
# Numbers pulled from the tables: Exp7 BIT_COMPL (XY=4030, Custom=2154);
# Exp6 MATRIX_TR. at BP=20% (XY=12658, Custom=10063); Exp2 BIT_COMPL at
# BP=70%/FIFO=8 (XY=2154, Custom=1489).
labels     = ["BIT_COMP\nFIFO=1", "MATRIX_TR\nBP=20%", "BIT_COMP\nFIFO=8"]
ratio_vals = [4030/2154, 12658/10063, 2154/1489]

xpos = np.arange(len(labels))
bars = axR.bar(xpos, ratio_vals, width=0.55, color=COLOR["Custom"],
               edgecolor="white", linewidth=0.7)
for b, v in zip(bars, ratio_vals):
    axR.text(b.get_x() + b.get_width()/2, v + 0.04,
             f"{v:.2f}× faster", ha="center", fontsize=10,
             color=COLOR["Custom"])
axR.axhline(1.0, color="0.5", lw=0.8, linestyle="--")
axR.text(len(labels) - 0.5, 1.05, "XY baseline",
         color="0.4", ha="right", fontsize=9)
axR.set_xticks(xpos)
axR.set_xticklabels(labels, fontsize=10)
axR.set_ylim(0, max(ratio_vals) * 1.3)
style_ax(axR, title="Custom routing vs. XY — speed-up at worst cases",
         ylabel="Speed-up (×)")

fig.suptitle("Torus 4×4 NoC — Custom routing wins, especially when it matters",
             y=1.02, fontsize=14, fontweight="bold")
save(fig, "00_cover_figure")
plt.show()
"""))

# -----------------------------------------------------------------------------
# Closing
# -----------------------------------------------------------------------------
CELLS.append(("md", r"""## Saved figures

All PNGs live in `notebooks/figures/` at 300 dpi — drop directly into the
report or slides.

```
notebooks/figures/
├── 00_cover_figure.png
├── exp1_fifo_sweep.png
├── exp2_routing_x_pattern.png
├── exp3_hotspot_sweep.png
├── exp4_backpressure.png
├── exp6_heavy_bp.png
├── exp7_fifo1_headofline.png
├── exp8_2d_heatmap.png
├── exp9_throughput_latency_tradeoff.png
├── exp10_pattern_x_fifo_matrix.png
└── exp11_load_scaling.png
```

Raw data: `docs/results.md` (markdown tables) and
`docs/results_workload.csv` (machine-readable rows)."""))


# -----------------------------------------------------------------------------
# Build the .ipynb JSON
# -----------------------------------------------------------------------------
def make_cell(kind: str, source: str):
    src_lines = [ln + "\n" for ln in source.split("\n")]
    # Strip the trailing newline on the very last line so cells don't
    # accumulate blank ends.
    if src_lines:
        src_lines[-1] = src_lines[-1].rstrip("\n")
    if kind == "md":
        return {
            "cell_type": "markdown",
            "metadata": {},
            "source": src_lines,
        }
    else:
        return {
            "cell_type": "code",
            "execution_count": None,
            "metadata": {},
            "outputs": [],
            "source": src_lines,
        }

nb = {
    "cells": [make_cell(k, s) for k, s in CELLS],
    "metadata": {
        "kernelspec": {
            "display_name": "Python 3",
            "language":     "python",
            "name":         "python3",
        },
        "language_info": {
            "name":            "python",
            "pygments_lexer":  "ipython3",
            "version":         "3.x",
        },
    },
    "nbformat":       4,
    "nbformat_minor": 5,
}

OUT_NB.parent.mkdir(parents=True, exist_ok=True)
OUT_NB.write_text(json.dumps(nb, indent=1))
print(f"Wrote notebook with {len(CELLS)} cells -> {OUT_NB}")
