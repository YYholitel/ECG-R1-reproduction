#!/usr/bin/env python3
"""Compare model output against ground truth for the real samples, matched by image."""
import json, os, re, sys

LABELS = [
    ("atrial flutter",       ["atrial flutter"]),
    ("atrial fibrillation",  ["atrial fibrillation", "atrial fib"]),
    ("sinus bradycardia",    ["sinus bradycardia"]),
    ("sinus tachycardia",    ["sinus tachycardia"]),
    ("sinus arrhythmia",     ["sinus arrhythmia"]),
    ("sinus rhythm",         ["sinus rhythm", "normal sinus"]),
]

def label(text):
    t = " " + re.sub(r"<[^>]+>", " ", text).lower() + " "
    for name, keys in LABELS:
        if any(k in t for k in keys):
            return name
    return "other"

def final_part(t):
    p = re.split(r"</think>", t)
    return p[-1] if len(p) > 1 else t

def hr(t):
    m = re.findall(r"(\d{2,3})\s*(?:bpm|beats per minute)", t, re.I)
    return int(m[0]) if m else None

def main(result_file, dataset_file):
    results = [json.loads(l) for l in open(result_file) if l.strip()]
    records = [json.loads(l) for l in open(dataset_file) if l.strip()]
    by_img = {os.path.basename(r["images"][0]): r for r in records if r.get("images")}

    rows, unmatched = [], 0
    for res in results:
        imgs = res.get("images") or []
        base = os.path.basename(imgs[0]["path"]) if imgs and isinstance(imgs[0], dict) else None
        rec = by_img.get(base) if base else None
        if rec is None:
            unmatched += 1
            continue
        gt = rec["messages"][-1]["content"]
        out = res["response"]
        gl, pl = label(gt), label(final_part(out))
        ghr, phr = hr(gt), hr(final_part(out))
        rows.append((rec["id"], gl, pl, ghr, phr, abs(ghr-phr) if ghr and phr else None, gl == pl))

    print(f"results {len(results)} | dataset {len(records)} | matched {len(rows)} | unmatched {unmatched}\n")
    print(f"{'id':<11}{'ground truth':<21}{'model':<21}{'GT':>4}{'mdl':>5}{'err':>5}  ok")
    print("-" * 76)
    for rid, gl, pl, ghr, phr, err, ok in rows:
        print(f"{rid:<11}{gl:<21}{pl:<21}{str(ghr):>4}{str(phr):>5}{str(err):>5}  {'Y' if ok else 'N'}")

    n = len(rows)
    agree = sum(1 for r in rows if r[6])
    errs = [r[5] for r in rows if r[5] is not None]
    print()
    print(f"节律分类一致 : {agree}/{n} = {100.0*agree/n:.1f}%")
    if errs:
        print(f"心率绝对误差 : 平均 {sum(errs)/len(errs):.1f} bpm (最大 {max(errs)}), 覆盖 {len(errs)} 条")
    # confusion for the misses
    print("\n错分类型:")
    from collections import Counter
    c = Counter((r[1], r[2]) for r in rows if not r[6])
    for (g, p), k in c.most_common():
        print(f"  金标准 {g} -> 模型 {p} : {k} 例")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])