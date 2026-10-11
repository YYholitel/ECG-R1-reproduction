# ECG-R1 数据盘点（2026-10-11）

本记录是对服务器 `nccserv0` 上 `/data/lihy` 的只读盘点。检查了 JSONL 解析和引用路径是否存在；尚未逐张解码图像或验证波形内容。服务器其他用户目录及共享挂载不在本次范围内。

## 当前数据

项目使用的数据根目录是 `/data/lihy/stray_from_repo/ECG-Protocol-Guided-Grounding-CoT`。仓库内 `ECG-Protocol-Guided-Grounding-CoT/` 另有一份 JSONL，其图像和波形目录没有可用数据。

前一个数据根目录有 **32,381 张** `gen_images/mimic_gen` PNG（约 23 GB）。这些图像覆盖 30k SFT、3,948 条 RL 和 2,381 条 Grounding 测试记录的全部图像引用。`ecg_timeseries` 只有占位文件；引用的 WFDB 波形路径均未找到成对的 `.hea` 与 `.dat` 文件。扫描到的 JSONL 均可解析，没有 JSON 语法错误。

| 数据集 | JSONL 记录 | 图像存在 | 波形存在 |
| --- | ---: | ---: | ---: |
| Protocol-Guided CoT SFT 30k | 30,000 | 30,000/30,000 | 0/30,000 |
| RL 4k | 3,948 | 3,948/3,948 | 0/3,948 |
| ECGInstruct | 1,156,110 | 0/1,156,110 | 0/1,156,110 |
| MIMIC Grounding full test | 2,381 | 2,381/2,381 | 0/2,381 |
| ECG-Bench：CODE-15% | 1,400 | 0/1,400 | 0/1,400 |
| ECG-Bench：CPSC2018 | 2,061 | 0/2,061 | 0/2,061 |
| ECG-Bench：CSN | 1,611 | 0/1,611 | 0/1,611 |
| ECG-Bench：Georgia | 2,026 | 0/2,026 | 0/2,026 |
| ECG-Bench：PTB-XL | 2,082 | 0/2,082 | 0/2,082 |

`ECGInstruct` 的图像引用分布为 `mimic` 87,142 条、`mimic_v4` 712,545 条、`ptb-xl` 288,783 条、`code15_v4` 67,640 条；这些图像目录均未就位。其波形引用涉及 MIMIC-IV-ECG、PTB-XL 和 CODE-15%。ECG-Bench 还需要 CPSC2018、CSN 和 Georgia 的图像和波形。

Grounding 的八份模态缺失 JSONL 每份均有 2,381 条记录。缺失某模态是实验设计：100% ECG 缺失版本不需要波形，其 2,381 张图像已齐全；凡仍引用波形的版本，目前都缺少波形。

跨全部 JSONL 去重后，共引用 **771,636 个不同图像路径**，其中 **32,381 个存在、739,255 个不存在**；共引用 **708,877 个不同波形路径**，目前没有完整的 `.hea` + `.dat` 文件对。这是路径并集，不能把各数据集样本数直接相加当作下载量。

RL JSONL 的 3,948 条记录均有非空 `labels` 和 `solution`；`heart_rate` 有 3 条为空。字段存在不等于奖励计算已验证。

## 模型与实验状态

- 官方 ECG-R1-8B-RL 四个权重分片和 ECG-CoCa 的 `cpt_wfep_epoch_20.pt` 已在 `/data/lihy`；已有推理结果见 [复现记录](REPRODUCTION_NOTES.md)。
- 未在 `/data/lihy` 找到 Qwen3-VL-8B-Instruct 初始化权重或自行训练的 SFT checkpoint。
- 已有 5 条和 50 条真实图像推理记录；50 条的节律标签关键词一致性为 41/50、心率平均绝对误差 4.8 bpm。这不是官方评测指标。官方完整评测、SFT、RL 与消融均未完成。
- `sft_train.sh`、`rl_train_dapo.sh` 和 `rl_train_rollout.sh` 仍有数据或 checkpoint 路径占位符。SFT 脚本中的 CoT 文件名也与实际 `*-30k.jsonl` 不一致。
- 盘点时 `/data` 文件系统约有 3.6 TB 可用空间。

## 下一步的数据缺口

1. 获取并整理 MIMIC-IV-ECG、PTB-XL、CODE-15%、CPSC2018、CSN、Georgia 的原始波形，按 JSONL 引用路径检查 `.hea`/`.dat`。
2. 获取 ECGInstruct 的四类图像和 ECG-Bench 的五类图像，复核所有引用路径。
3. 获取 SFT 初始化模型 Qwen3-VL-8B-Instruct，修正训练脚本路径；然后先运行官方最终模型评测，再开展自行 SFT/RL 训练。
