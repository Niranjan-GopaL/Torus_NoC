#!/bin/bash
# =============================================================================
# _env.sh — single source of truth for paths used by every shell + TCL script.
#
# Sourced by every script in scripts/, and read (via `env(NAME)`) by every TCL
# script in tcl/. Edit the USER CONFIG block below for your machine; the rest
# is derived. Every variable is exported so child processes (Vivado, child
# bash scripts) inherit them.
# =============================================================================

# -----------------------------------------------------------------------------
# USER CONFIG — edit these three lines if your machine layout differs
# -----------------------------------------------------------------------------

# Parent directory under which the Vivado .xpr will live. The project itself
# goes in $VIVADO_PROJECTS_DIR/$PROJ_NAME/.
: "${VIVADO_PROJECTS_DIR:=$HOME/vivado_projects}"

# Project name (used as the .xpr filename and the project sub-directory).
: "${PROJ_NAME:=Torus_4x4_extensive_tests}"

# Path to the vivado binary. Override via env var if Vivado lives elsewhere:
#     VIVADO=/opt/Xilinx/Vivado/2023.2/bin/vivado bash scripts/run_full_rerun.sh
: "${VIVADO:=/tools/Xilinx/Vivado/2024.2/bin/vivado}"


# -----------------------------------------------------------------------------
# DERIVED PATHS — do not edit
# -----------------------------------------------------------------------------

# Resolve final/ from this script's own location, so the whole tree is
# relocatable. mv final/ anywhere and everything still works.
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"

SRC_DIR="$ROOT_DIR/src"
TB_DIR="$ROOT_DIR/src/tb"
TCL_DIR="$ROOT_DIR/tcl"
SCRATCH_DIR="$ROOT_DIR/claude_stratchpad_workpsace"
DOCS_DIR="$ROOT_DIR/docs"

PROJ_DIR="$VIVADO_PROJECTS_DIR/$PROJ_NAME"
PROJ_XPR="$PROJ_DIR/$PROJ_NAME.xpr"

RESULTS_FILE="$DOCS_DIR/results.md"
RESULTS_CSV="$DOCS_DIR/results_workload.csv"

# Export everything — TCL scripts read these with `$env(NAME)`, and child
# shell scripts inherit them without needing to re-source this file.
export VIVADO_PROJECTS_DIR PROJ_NAME VIVADO
export SCRIPTS_DIR ROOT_DIR SRC_DIR TB_DIR TCL_DIR SCRATCH_DIR DOCS_DIR
export PROJ_DIR PROJ_XPR RESULTS_FILE RESULTS_CSV

mkdir -p "$SCRATCH_DIR/tcl" "$SCRATCH_DIR/logs"
