# Evaluation records

Small evidence files from the two inference runs done on 2026-10-09. They exist so
the results can be inspected without re-downloading anything: the ECG images alone
would otherwise cost a 21.4 GB archive download (see
`scripts/utils/fetch_mimic_images.py`).

Everything here is tiny by design. Weights, datasets and caches stay outside the
repository; see the root `.gitignore`.

| file | what it is |
|---|---|
| `env_check_report.txt` | `scripts/shells/check_env.sh` output proving the dependency set |
| `real/real_samples.jsonl` | 5 real MIMIC-IV test records, each carrying its ground-truth interpretation |
| `real/images/*.png` | the five ECG images those records refer to |
| `real/run_without_env.jsonl` | model output **without** the upstream env vars (mean HR error 17.8 bpm) |
| `real/run_with_upstream_env.jsonl` | model output **with** `IMAGE_MAX_TOKEN_NUM=768` et al (mean HR error 4.4 bpm) |
| `smoke/infer.log` | first end-to-end run, on a synthetic image, before any real data was available |

The env-var comparison is the substantive result: leaving `IMAGE_MAX_TOKEN_NUM` unset
changes how much of the ECG image survives preprocessing and makes the model
systematically under-read the heart rate. Always source the upstream settings from
`scripts/shells/inference.sh`.