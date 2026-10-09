#!/bin/bash

export NPROC_PER_NODE=4
export CUDA_VISIBLE_DEVICES=0,1,2,4
export MASTER_PORT=29550

export IMAGE_MAX_TOKEN_NUM=768
export ECG_SEQ_LENGTH=5000
export ECG_PATCH_SIZE=50

export ROOT_ECG_DIR='/data/lihy/stray_from_repo/ECG-Protocol-Guided-Grounding-CoT/ecg_timeseries'
export ROOT_IMAGE_DIR='/data/lihy/stray_from_repo/ECG-Protocol-Guided-Grounding-CoT/ecg_images'

export ECG_TOWER_PATH='/data/lihy/ECG-R1_repoduction/ecg_coca/open_clip/checkpoint/cpt_wfep_epoch_20.pt'

export ECG_PROJECTOR_TYPE='mlp2x_gelu'
export ECG_MODEL_CONFIG='coca_ViT-B-32'
export FREEZE_ECG_TOWER=True
export FREEZE_ECG_PROJECTOR=True

swift infer \
    --model /data/lihy/model_cache/ECG-R1-8B-RL \
    --model_type ecg_r1 \
    --template ecg_r1 \
    --torch_dtype bfloat16 \
    --custom_register_path 'ecg_r1/register.py' \
    --infer_backend pt \
    --val_dataset /data/lihy/stray_from_repo/ECG-Protocol-Guided-Grounding-CoT/ecg_jsons/test_set/ecg-grounding-test-mimiciv_ecg_missing100.jsonl \
    --max_batch_size 4 \
    --task_type causal_lm \
    --max_new_tokens 512 \
    --temperature 0.0 \
    --repetition_penalty 1.0 \
    --use_hf true