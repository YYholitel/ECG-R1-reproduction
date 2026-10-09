#!/usr/bin/env bash
# Inference over a handful of REAL MIMIC-IV test samples.
#
# The images come from ecg_images/gen_images/mimic_gen.zip (21.4 GB, 87553
# entries) and were pulled out on demand with HTTP range requests on a machine
# that can reach HuggingFace reliably, then copied here. Ground-truth
# interpretations travel in the same records, so output quality is checkable.
#
#   bash scripts/shells/infer_real_samples.sh
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
cd "$PROJ"

DATASET=${DATASET:-/data/lihy/result/real/real_samples.jsonl}
MAX_NEW_TOKENS=${MAX_NEW_TOKENS:-1024}
export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}

# Mirror the upstream scripts/shells/inference.sh settings. IMAGE_MAX_TOKEN_NUM in
# particular controls how much of the ECG image survives the image processor, and
# leaving it unset measurably changed the reported heart rates.
export IMAGE_MAX_TOKEN_NUM=${IMAGE_MAX_TOKEN_NUM:-768}
export ECG_SEQ_LENGTH=${ECG_SEQ_LENGTH:-5000}
export ECG_PATCH_SIZE=${ECG_PATCH_SIZE:-50}
export ECG_PROJECTOR_TYPE=${ECG_PROJECTOR_TYPE:-mlp2x_gelu}
export ECG_MODEL_CONFIG=${ECG_MODEL_CONFIG:-coca_ViT-B-32}
export FREEZE_ECG_TOWER=${FREEZE_ECG_TOWER:-True}
export FREEZE_ECG_PROJECTOR=${FREEZE_ECG_PROJECTOR:-True}

echo "dataset       : $DATASET"
echo "model         : $MODEL_DIR"
echo "max_new_tokens: $MAX_NEW_TOKENS"
echo

swift infer \
    --model "$MODEL_DIR" \
    --model_type ecg_r1 \
    --template ecg_r1 \
    --torch_dtype bfloat16 \
    --custom_register_path ecg_r1/register.py \
    --infer_backend pt \
    --val_dataset "$DATASET" \
    --max_batch_size 1 \
    --max_new_tokens "$MAX_NEW_TOKENS" \
    --temperature 0.0 \
    --task_type causal_lm \
    --use_hf true