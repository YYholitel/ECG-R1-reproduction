#!/usr/bin/env python3
"""Fetch only the ECG images a test set actually needs, out of mimic_gen.zip.

The MIMIC-IV images referenced by
`ecg_jsons/test_set/ecg-grounding-test-mimiciv_*.jsonl` are published as a single
21.4 GB zip (`ecg_images/gen_images/mimic_gen.zip` in LANSG/ECG-Grounding, 87,553
entries). Downloading that in full is pointless when only a handful of samples is
needed, so this reads the zip's central directory over HTTP range requests and pulls
just the requested members - about 0.8 MB per image instead of 21.4 GB in total.

Run it from a machine that can reach HuggingFace reliably. On nccserv0 the
xet-bridge link is intermittent, so this was run on the Windows side and the
extracted images were copied to the GPU host with scp.

    python fetch_mimic_images.py --jsonl ecg_missing_test.jsonl --n 5 --dest ./images
    python fetch_mimic_images.py --ids 49722328 49975043 --dest ./images

Requires: pip install remotezip
"""
import argparse
import json
import os
import sys

URL = ("https://hf-mirror.com/datasets/LANSG/ECG-Grounding/resolve/main/"
       "ecg_images/gen_images/mimic_gen.zip")


def basenames_from_jsonl(path, n):
    out = []
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            imgs = json.loads(line).get("images") or []
            if imgs:
                out.append(os.path.basename(imgs[0]))
            if len(out) >= n:
                break
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--jsonl", help="test-set jsonl to take image names from")
    ap.add_argument("--n", type=int, default=5, help="how many records (default 5)")
    ap.add_argument("--ids", nargs="*", help="explicit sample ids, e.g. 49722328")
    ap.add_argument("--dest", required=True, help="directory to extract into")
    ap.add_argument("--url", default=URL)
    args = ap.parse_args()

    if args.ids:
        targets = [i if i.endswith(".png") else f"{i}-0.png" for i in args.ids]
    elif args.jsonl:
        targets = basenames_from_jsonl(args.jsonl, args.n)
    else:
        ap.error("give either --jsonl or --ids")

    from remotezip import RemoteZip

    os.makedirs(args.dest, exist_ok=True)
    print(f"targets: {targets}")
    with RemoteZip(args.url) as z:
        names = z.namelist()
        print(f"zip entries: {len(names)}")
        missing = []
        for base in targets:
            member = next((n for n in names if n.endswith(base)), None)
            if member is None:
                missing.append(base)
                print(f"  {base}: NOT FOUND")
                continue
            out = os.path.join(args.dest, member)
            if os.path.exists(out) and os.path.getsize(out) > 0:
                print(f"  {base}: already present ({os.path.getsize(out)} bytes)")
                continue
            z.extract(member, path=args.dest)
            print(f"  {base}: {os.path.getsize(out)} bytes  <- {member}")
    if missing:
        print(f"missing: {missing}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())