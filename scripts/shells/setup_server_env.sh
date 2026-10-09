#!/usr/bin/env bash
# Idempotent base-environment setup for the ECG-R1 reproduction (nccserv0).
# Safe to re-run after every `git pull`; pip no-ops anything already satisfied.
#
#   bash scripts/shells/setup_server_env.sh
#
# Version constraints that must hold together:
#   * vLLM 0.11.0 pins torch == 2.8.0        -> install the cu126 build
#   * vLLM 0.11.0 needs transformers >= 4.55.2
#   * this project caps transformers < 4.58
#   => transformers is pinned inside that window.
#
# Why ms-swift is installed with --no-deps, and why autoawq/auto_gptq are dropped:
#   ms_swift's install_requires is parsed straight from requirements.txt, which
#   lists autoawq and auto_gptq. Neither has a usable wheel here, and their sdist
#   build fails because the isolated build env cannot import torch. They are only
#   needed for AWQ/GPTQ quantized inference, which this reproduction does not use.
#   Filtering them out of requirements.txt and installing ms-swift itself with
#   --no-deps is therefore the reliable path.
set -uo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh" 2>/dev/null || true

PROJ=${PROJ:-/data/lihy/ECG-R1_repoduction}
TRANSFORMERS_PIN=${TRANSFORMERS_PIN:-4.57.1}
export TMPDIR=${TMPDIR:-/data/lihy/tmp}
export PIP_CACHE_DIR=${PIP_CACHE_DIR:-/data/lihy/pip_cache}
export PIP_INDEX_URL=${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}
export PIP_DEFAULT_TIMEOUT=${PIP_DEFAULT_TIMEOUT:-120}
PY=${PY:-/data/lihy/miniconda3/envs/ecg_r1/bin/python}

TORCH_WHL=https://download.pytorch.org/whl/cu126/torch-2.8.0%2Bcu126-cp310-cp310-manylinux_2_28_x86_64.whl
TV_WHL=https://download.pytorch.org/whl/cu126/torchvision-0.23.0%2Bcu126-cp310-cp310-manylinux_2_28_x86_64.whl

CONSTRAINTS=/data/lihy/ecg_constraints.txt
cat > "$CONSTRAINTS" <<EOF
transformers==$TRANSFORMERS_PIN
EOF

SAFE_REQ=/data/lihy/requirements_safe.txt
grep -vE '^[[:space:]]*(autoawq|auto_gptq)[[:space:]]*$' "$PROJ/requirements.txt" > "$SAFE_REQ"
echo "requirements_safe.txt: dropped $(grep -cE '^[[:space:]]*(autoawq|auto_gptq)[[:space:]]*$' "$PROJ/requirements.txt") package(s)"

step() { echo; echo "===== $* ====="; }

step "1/6 torch 2.8.0 + cu126 (skip if already present)"
if "$PY" -c 'import torch,sys; sys.exit(0 if torch.__version__.startswith("2.8.0+cu126") else 1)' 2>/dev/null; then
  echo "already installed: $("$PY" -c 'import torch;print(torch.__version__)')"
else
  "$PY" -m pip install "$TORCH_WHL" "$TV_WHL"
fi

step "2/6 ms-swift itself (no deps)"
"$PY" -m pip install -e "$PROJ" --no-deps

step "3/6 project dependencies (transformers pinned via constraints)"
"$PY" -m pip install -r "$SAFE_REQ" -c "$CONSTRAINTS"

step "4/6 deepspeed (sdist build, ops disabled)"
DS_BUILD_OPS=0 "$PY" -m pip install deepspeed --no-build-isolation -c "$CONSTRAINTS"

step "5/6 ECG-R1 vLLM plugin"
"$PY" -m pip install -e "$PROJ/ecg_r1" --no-deps

step "6/6 verification"
"$PY" -m pip check || echo "WARN: pip check reported conflicts - review above"
bash "$PROJ/scripts/shells/check_env.sh"
