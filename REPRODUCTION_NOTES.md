# ECG-R1 reproduction log

## Stage 1: environment and official weights — COMPLETE and verified (2026-10-09)

Host `nccserv0`; project `/data/lihy/ECG-R1_repoduction`; conda env
`/data/lihy/miniconda3/envs/ecg_r1` (Python 3.10.22); 8x RTX 3090, driver 565.57.01
(reports CUDA 12.7).

Run `bash scripts/shells/check_env.sh` for the live version/inventory report; the
verified result on this date was `RESULT: ALL OK` with:

    torch 2.8.0+cu126   torchvision 0.23.0+cu126   transformers 4.57.1
    vllm 0.11.0         deepspeed 0.19.7           sglang 0.3.6.post2
    ms-swift 3.9.0      peft 0.14.0  trl 0.23.1    datasets 3.6.0
    qwen_vl_utils 0.0.14  timm 1.0.30  safetensors 0.8.0  ecg-r1 0.1.0

`torch==2.8.0` is not a free choice: vLLM 0.11.0 pins it, and transformers must sit
in `[4.55.2, 4.58)` to satisfy vLLM's floor and this project's cap at the same time.

### Weights — both verified byte-for-byte

| artifact | bytes | verification |
|---|---|---|
| `PKUDigitalHealth/ECG-R1-8B-RL` @ `f9257759e2e3d6b1864c2e1af4dfaa8e96eb84ea` | 17,741,876,040 (4 shards) | all four SHA-256 match the HF manifest; `/data/lihy/model_cache/ECG-R1-8B-RL_verify.log` |
| ECG-CoCa `cpt_wfep_epoch_20.pt` | 4,083,453,582 | sha256 `64c8acfc389018f1e91c69973869c6fe8a199afbd608726f3c78d0a14961f631`; loads as a 666-entry state_dict |

The ECG-CoCa checkpoint sits at `ecg_coca/open_clip/checkpoint/` (per the upstream
README) with a symlink at `ecg_coca/checkpoint/` because `config.json` names that
second path. It **is** required: `register.py` finds no attached tower at init time
and builds it from this file.

### Deviations that were necessary (all encoded in the scripts)

1. `autoawq` / `auto_gptq` are dropped from `requirements.txt`, and `ms-swift` is
   installed with `--no-deps`. Neither package has a usable wheel here, their sdist
   build fails, and ms-swift parses `requirements.txt` as its `install_requires`, so
   one broken package aborts the whole install. They are only needed for AWQ/GPTQ
   quantized inference, which this reproduction does not use.
2. `torchao` is uninstalled. It arrives transitively, nothing declares it, and
   release 0.18 imports `ScalingType` from `torch.nn.functional`, which only exists
   in torch >= 2.11. transformers guards it by version alone, so a broken torchao
   breaks `import peft` -> `import swift` outright.
3. `ecg_coca/training/main.py::get_ecg_encoder` passes `pretrained_hf=False`. The CoCa
   config names `ncbi/MedCPT-Query-Encoder` as its text tower, and without this flag
   open_clip fetches it from the hub — which fails here, because huggingface.co is
   unreachable and the xet bridge times out. The text tower weights are already part
   of the local `cpt_wfep_epoch_20.pt`, so the fetch is pure waste.
4. `scripts/shells/env.sh` centralizes `HF_HUB_CACHE=/data/lihy/model_cache/hub`,
   `HF_ENDPOINT=https://hf-mirror.com` and `HF_HUB_DISABLE_XET=1` (the xet bridge
   bypasses the mirror and times out). Putting these in `~/.bashrc` does not work:
   Ubuntu's `.bashrc` returns early for non-interactive shells, so scripts never see it.

### Inference smoke test — PASSED

`bash scripts/shells/smoke_infer.sh` generates a synthetic 12-lead ECG image and runs
one forward pass from the local checkpoint, with `ECG_TOWER_PATH` deliberately unset.

    num_prompt_tokens 1472 | num_generated_tokens 128 | runtime 5.71 s | 22.4 tokens/s
    peak GPU memory 17.2 GB on one RTX 3090 | 0 errors

The model printed a protocol-shaped interpretation (`**Step 1: Technical, Rate &
Rhythm** ... **Step 2: Conduction, Axis & Intervals**`), and the loaded module tree
shows `ecg_tower` plus `ecg_projector` attached.

### Repository automation

`scripts/shells/autogit.sh` runs from cron every 30 minutes: it commits and pushes
whatever changed, and refuses to stage any file above 3000 MB (agreed ceiling) or
above GitHub's 100 MB per-file limit. Model binaries stay on the server; this
repository keeps only the reproducible setup record.

### Still outstanding

- Real data has not been downloaded; `inference.sh` still carries `/path/to` placeholders.
- Training (SFT/RL) has not been attempted.
- Evaluation scripts have not been run against the official test sets.
## First real evaluation signal: 5 MIMIC-IV samples (2026-10-09)

Not a benchmark - five samples - but the first end-to-end check against ground truth.
The real images were pulled out of `ecg_images/gen_images/mimic_gen.zip` (21.4 GB,
87,553 entries) with HTTP range requests run on the Windows side, because this host's
xet-bridge link to HuggingFace is intermittent. Only ~4 MB moved for five images.
Ground truth travels inside the same records, so the output is checkable.

| id | ground truth | model output (upstream env) | HR error |
|---|---|---|---|
| 49722328 | atrial fibrillation | atrial fibrillation | -6 |
| 49975043 | sinus rhythm, 62 bpm | sinus rhythm, 64 bpm (+ APC, LVH) | +2 |
| 42162044 | sinus rhythm, 74 bpm | normal sinus rhythm, 72 bpm | -2 |
| 46936047 | **atrial flutter**, rapid response, 135 bpm | **sinus tachycardia**, 128 bpm (+ LBBB) | -7 |
| 47772418 | sinus rhythm, normal ECG, 88 bpm | normal sinus rhythm, 83 bpm | -5 |

Four of five rhythm classifications agree. The miss is atrial flutter read as sinus
tachycardia, which is the hardest distinction in this set.

### The upstream env vars matter far more than expected

`scripts/shells/inference.sh` exports `IMAGE_MAX_TOKEN_NUM=768` and friends. Running
without them lets each sample carry ~3700 image tokens instead of ~808, and heart-rate
accuracy collapses:

| run | mean absolute HR error |
|---|---|
| without the env vars | 17.8 bpm, always an underestimate |
| with the env vars | 4.4 bpm |

`IMAGE_MAX_TOKEN_NUM` is not cosmetic; it changes what the model can read off the
image. Any inference run must source the upstream settings.

### Failure modes to watch on larger sets

- Atrial flutter is called atrial fibrillation, or sinus tachycardia.
- LVH and bundle branch block are over-reported relative to ground truth.
### Getting real test images without the 21.4 GB download

`scripts/utils/fetch_mimic_images.py` pulls only the images a given test-set jsonl
references, using HTTP range requests against `mimic_gen.zip`. Five images cost about
4 MB instead of 21.4 GB, in roughly 30 seconds. Run it where HuggingFace is reachable
(the Windows side, in this setup) and copy the extracted tree to the GPU host; then
point the records' `images` field at the local absolute paths.