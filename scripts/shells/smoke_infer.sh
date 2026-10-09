#!/usr/bin/env bash
# Minimal end-to-end inference smoke test.
#
# Proves that the environment can (a) load PKUDigitalHealth/ECG-R1-8B-RL from the
# verified local copy and (b) run one forward pass on a synthetic ECG image,
# without needing any of the real datasets.
#
#   bash scripts/shells/smoke_infer.sh
#
# Deliberately does NOT set ECG_TOWER_PATH: the HF checkpoint already ships
# model.ecg_tower.* weights, and ecg_r1/register.py returns early when the tower
# is attached, so the separate cpt_wfep_epoch_20.pt file is not required.
# This script is therefore also the test of that claim.
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"
cd "$PROJ"

OUT=${OUT:-/data/lihy/result/smoke}
mkdir -p "$OUT"

echo "===== 1/2 generating a synthetic 12-lead ECG image ====="
"$PY" - "$OUT" <<'PYEOF'
import json, math, sys
from pathlib import Path
from PIL import Image, ImageDraw

out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
img_path = out / "synthetic_ecg.png"

W, H = 1400, 1020
img = Image.new("RGB", (W, H), "white")
d = ImageDraw.Draw(img)
for x in range(0, W, 20):
    d.line([(x, 0), (x, H)], fill=(245, 218, 218), width=1)
for y in range(0, H, 20):
    d.line([(0, y), (W, y)], fill=(245, 218, 218), width=1)

leads = ["I","II","III","aVR","aVL","aVF","V1","V2","V3","V4","V5","V6"]
scales = [0.8, 1.0, 0.6, -0.7, 0.4, 0.8, -0.5, 0.3, 0.8, 1.1, 1.0, 0.8]
for idx, (lead, scale) in enumerate(zip(leads, scales)):
    row, col = divmod(idx, 2)
    left = 90 + col * 680
    baseline = 110 + row * 160
    d.text((left, baseline - 65), lead, fill="black")
    pts = []
    for off in range(600):
        ph = (off % 200) / 200.0
        wave = (0.10 * math.exp(-((ph - 0.16) / 0.045) ** 2)
                - 0.18 * math.exp(-((ph - 0.38) / 0.012) ** 2)
                + 1.00 * math.exp(-((ph - 0.41) / 0.009) ** 2)
                - 0.25 * math.exp(-((ph - 0.44) / 0.015) ** 2)
                + 0.28 * math.exp(-((ph - 0.68) / 0.075) ** 2))
        pts.append((left + off, round(baseline - 65 * scale * wave)))
    d.line(pts, fill=(25, 25, 25), width=2)
img.save(img_path)

record = {
    "id": "synthetic_format_smoke",
    "messages": [
        {"role": "system", "content": "You are a helpful, harmless clinical ECG assistant. Provide concise, evidence-based interpretations."},
        {"role": "user", "content": "<image>\nInterpret the provided ECG image, identify key features and abnormalities in each lead, and generate a clinical diagnosis that is supported by the observed evidence."},
    ],
    "images": [str(img_path)],
    "objects": {"ecg": []},
}
ds = out / "sample.jsonl"
ds.write_text(json.dumps(record, ensure_ascii=False) + "\n")
print("image   :", img_path)
print("dataset :", ds)
PYEOF

echo
echo "===== 2/2 running inference (single GPU) ====="
unset ECG_TOWER_PATH || true
export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}
echo "model        : $MODEL_DIR"
echo "CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES"
echo "ECG_TOWER_PATH: ${ECG_TOWER_PATH:-<unset, tower must come from the checkpoint>}"
echo
swift infer \
    --model "$MODEL_DIR" \
    --model_type ecg_r1 \
    --template ecg_r1 \
    --torch_dtype bfloat16 \
    --custom_register_path ecg_r1/register.py \
    --infer_backend pt \
    --val_dataset "$OUT/sample.jsonl" \
    --max_batch_size 1 \
    --max_new_tokens 128 \
    --temperature 0.0 \
    --task_type causal_lm \
    --use_hf true 2>&1 | tee "$OUT/infer.log"

echo
echo "===== output files ====="
ls -l "$OUT"
