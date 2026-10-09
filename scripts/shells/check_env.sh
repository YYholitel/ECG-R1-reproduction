#!/usr/bin/env bash
# ECG-R1 environment verification: imports, versions, CUDA visibility.
# Usage: bash scripts/shells/check_env.sh
# Does not require exclusive GPU access; allocates only a few MB on cuda:0.
set -uo pipefail
PY=/data/lihy/miniconda3/envs/ecg_r1/bin/python

echo "=== ECG-R1 environment check ==="
date
echo
echo "--- interpreter ---"
"$PY" -V
echo
echo "--- installed versions ---"
"$PY" - <<'PYEOF'
import importlib.metadata as md
for p in ["torch","torchvision","vllm","transformers","tokenizers","accelerate","peft","trl",
          "deepspeed","sglang","datasets","qwen_vl_utils","timm","safetensors","ms-swift","ecg-r1"]:
    try:
        print(f"  {p:16s} {md.version(p)}")
    except Exception:
        print(f"  {p:16s} <not installed>")
PYEOF
echo
echo "--- imports + CUDA ---"
"$PY" - <<'PYEOF'
import sys
fail = []
def check(label, fn):
    try:
        print(f"  {label:34s} OK   {fn()}")
    except Exception as e:
        fail.append(label)
        print(f"  {label:34s} FAIL {type(e).__name__}: {e}")

def _torch():
    import torch
    return f"{torch.__version__} (cuda {torch.version.cuda})"
def _cuda():
    import torch
    n = torch.cuda.device_count()
    if not torch.cuda.is_available():
        raise RuntimeError("torch.cuda.is_available() is False")
    x = torch.randn(1000, 1000, device="cuda:0")
    s = float((x @ x).sum())
    return f"{n} device(s), device0={torch.cuda.get_device_name(0)}, matmul={s:.0f}"

check("import torch", _torch)
check("CUDA usable (matmul on cuda:0)", _cuda)
check("import transformers", lambda: __import__("transformers").__version__)
check("import vllm", lambda: __import__("vllm").__version__)
check("import deepspeed", lambda: __import__("deepspeed").__version__)
check("import sglang", lambda: __import__("sglang").__version__)
check("import swift (ms-swift)", lambda: getattr(__import__("swift"), "__version__", "?"))
check("import ecg_r1 vllm plugin", lambda: __import__("ecg_r1").__file__)

import transformers
ver = transformers.__version__
bound = tuple(int(x) for x in ver.split(".")[:2])
if bound >= (4, 58):
    fail.append("transformers<4.58")
    print(f"  transformers version bound            FAIL {ver} violates the project cap <4.58")
else:
    print(f"  transformers version bound            OK   {ver} < 4.58")

print()
print("RESULT:", "ALL OK" if not fail else f"FAILURES: {fail}")
sys.exit(0 if not fail else 1)
PYEOF
