#!/usr/bin/env bash
source "$(dirname "$0")/env.sh" 2>/dev/null || true
# Idempotent base-environment setup for the ECG-R1 reproduction (server nccserv0).
# Safe to re-run after every `git pull`; pip no-ops anything already satisfied.
#
#   bash scripts/shells/setup_server_env.sh
#
# Version constraints that must hold together:
#   * vLLM 0.11.0 pins torch == 2.8.0        -> install the cu126 build
#   * vLLM 0.11.0 needs transformers >= 4.55.2
#   * this project caps transformers < 4.58
#   => transformer pin below sits inside that window.
set -euo pipefail

PROJ=${PROJ:-/data/lihy/ECG-R1_repoduction}
CONDA=${CONDA:-/data/lihy/miniconda3}
ENVNAME=${ENVNAME:-ecg_r1}
TRANSFORMERS_PIN=${TRANSFORMERS_PIN:-4.57.1}

export TMPDIR=/data/lihy/tmp
export PIP_CACHE_DIR=/data/lihy/pip_cache
export PIP_INDEX_URL=${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}
export PIP_DEFAULT_TIMEOUT=120

source "$CONDA/etc/profile.d/conda.sh"
conda activate "$ENVNAME"
PY="$CONDA/envs/$ENVNAME/bin/python"
cd "$PROJ"

TORCH_WHL=https://download.pytorch.org/whl/cu126/torch-2.8.0%2Bcu126-cp310-cp310-manylinux_2_28_x86_64.whl
TV_WHL=https://download.pytorch.org/whl/cu126/torchvision-0.23.0%2Bcu126-cp310-cp310-manylinux_2_28_x86_64.whl

step() { echo; echo "===== $* ====="; }

step "1/6 torch 2.8.0 + cu126 (must match the vLLM 0.11.0 pin)"
"$PY" -m pip install "$TORCH_WHL" "$TV_WHL"

step "2/6 core project dependencies"
"$PY" -m pip install -e . "transformers==$TRANSFORMERS_PIN" wfdb timm ftfy qwen_vl_utils==0.0.14 scikit-learn

step "3/6 vLLM 0.11.0"
"$PY" -m pip install "vllm==0.11.0"

step "4/6 deepspeed (prebuilt, no op compilation)"
DS_BUILD_OPS=0 "$PY" -m pip install deepspeed

step "5/6 sglang (optional and heavy; failure is tolerated)"
"$PY" -m pip install "sglang[all]<0.5" || echo "WARN: sglang install failed - optional, continuing"

step "6/6 ECG-R1 vLLM plugin"
"$PY" -m pip install -e ./ecg_r1 --no-deps

step "dependency consistency (pip check)"
"$PY" -m pip check || echo "WARN: pip check reported conflicts - review above"

step "verification"
bash "$PROJ/scripts/shells/check_env.sh"
