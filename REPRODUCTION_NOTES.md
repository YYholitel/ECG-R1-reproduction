# ECG-R1 reproduction log

## Stage 1: environment and official model weights (in progress, 2026-10-09)

- Server: `nccserv0`; project: `/data/lihy/ECG-R1_repoduction`; Conda environment: `/data/lihy/miniconda3/envs/ecg_r1` (Python 3.10).
- GPU: eight RTX 3090 cards. Driver 565.57.01 reports CUDA 12.7, so PyTorch 2.8.0 with CUDA 12.6 is being installed.
- Official model: `PKUDigitalHealth/ECG-R1-8B-RL`, revision `f9257759e2e3d6b1864c2e1af4dfaa8e96eb84ea`.
- Model files are downloading to `/data/lihy/model_cache/ECG-R1-8B-RL`. The four safetensors files total 17,741,876,040 bytes. Download is complete; all four SHA-256 hashes match the official Hugging Face manifest. Verification log: `/data/lihy/model_cache/ECG-R1-8B-RL_verify.log`.
- Hugging Face cache for the ID is at `/data/lihy/model_cache/hub` (`HF_HUB_CACHE`); the snapshot points to the verified files. Direct access to `huggingface.co` timed out on this server. The download uses `https://hf-mirror.com` and the revision is recorded above.
- PyTorch, vLLM 0.11.0, SGLang `<0.5`, DeepSpeed, and project dependencies are being installed. Their import and GPU checks are **pending**.
- Inference has **not** been run. The official `scripts/shells/inference.sh` still contains placeholder model, dataset, and data paths; those must be set before running it.
- The repository loader also names a separate ECG-CoCa encoder checkpoint. The Hugging Face model index contains `model.ecg_tower.*` weights, but loading directly from the Hugging Face ID without the separate file has **not** been validated.

This log will be updated after installation and import checks finish. Model binaries and local caches stay on the server; GitHub contains the reproducible setup record.
