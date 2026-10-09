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