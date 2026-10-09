#!/usr/bin/env bash
# Shared environment for the ECG-R1 reproduction on nccserv0.
# Source it from other scripts:  source "$(dirname "$0")/env.sh"
#
# Why this file exists instead of ~/.bashrc: Ubuntu's default ~/.bashrc returns
# early for non-interactive shells, so exports placed there never reach scripts
# started via ssh, nohup, or sbatch - only interactive terminals.
export PROJ=${PROJ:-/data/lihy/ECG-R1_repoduction}
export CONDA=${CONDA:-/data/lihy/miniconda3}
export ENVNAME=${ENVNAME:-ecg_r1}
export PY="$CONDA/envs/$ENVNAME/bin/python"

export MODEL_ID=${MODEL_ID:-PKUDigitalHealth/ECG-R1-8B-RL}
export MODEL_DIR=${MODEL_DIR:-/data/lihy/model_cache/ECG-R1-8B-RL}
# Keep the HF cache on /data: the root filesystem is small and the verified
# 17.75 GB copy already lives there.
export HF_HUB_CACHE=${HF_HUB_CACHE:-/data/lihy/model_cache/hub}
# huggingface.co times out from this host; the mirror works.
export HF_ENDPOINT=${HF_ENDPOINT:-https://hf-mirror.com}
# hf-xet talks to cas-bridge.xethub.hf.co directly, which the mirror does not
# proxy and which times out from this host. Force the classic HTTPS path.
export HF_HUB_DISABLE_XET=${HF_HUB_DISABLE_XET:-1}

export TMPDIR=${TMPDIR:-/data/lihy/tmp}
export PIP_CACHE_DIR=${PIP_CACHE_DIR:-/data/lihy/pip_cache}
export PIP_DEFAULT_TIMEOUT=${PIP_DEFAULT_TIMEOUT:-120}

if [ -f "$CONDA/etc/profile.d/conda.sh" ]; then
  # shellcheck disable=SC1091
  source "$CONDA/etc/profile.d/conda.sh"
  conda activate "$ENVNAME" 2>/dev/null || true
fi
