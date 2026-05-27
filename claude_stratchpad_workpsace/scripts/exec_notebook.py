#!/usr/bin/env python3
"""Execute every code cell of report_plots.ipynb and save figures."""
import json
from pathlib import Path

NB = Path(__file__).resolve().parents[2] / "notebooks" / "report_plots.ipynb"
nb = json.loads(NB.read_text())

# Run all code cells in one shared namespace so later cells see earlier vars
ns = {"__name__": "__main__"}
import matplotlib
matplotlib.use("Agg")           # headless, no GUI window pop-up
import matplotlib.pyplot as plt
ns["plt"] = plt

for i, cell in enumerate(nb["cells"]):
    if cell["cell_type"] != "code":
        continue
    src = "".join(cell["source"])
    print(f"=== cell {i:02d} ===")
    try:
        exec(compile(src, f"<cell {i}>", "exec"), ns)
    except Exception as e:
        print(f"  !! {type(e).__name__}: {e}")
        raise
print("All cells executed cleanly.")
