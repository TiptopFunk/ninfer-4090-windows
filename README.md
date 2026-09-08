# NInfer 4090 Windows

> Windows port of NInfer for the NVIDIA GeForce RTX 4090 (`sm_89`, Ada Lovelace). Selected checkpoints. Maximum single-GPU inference performance. **100% Native Windows MSVC (no WSL2 required).**

**[⬇️ Descargar versión precompilada portable v1.0.7 (Windows 11) en GitHub Releases](https://github.com/Ambolio/ninfer-4090-windows/releases/download/v1.0.7-windows/ninfer-4090-windows-v1.0.7.zip)**

NInfer 4090 Windows is a native Windows 11 port of the upstream
[Neroued/ninfer](https://github.com/Neroued/ninfer) C++20/CUDA inference engine,
adapted to the Ada Lovelace architecture (`sm_89`): kernels fitted to the
48 KiB static shared-memory limit, the E8-lattice `rk4v4-e8` KV storage, MTP3
and DFlash2 speculative decoding, and the WDDM evictable-budget bypass. It
runs text, image, and video prompts through a local CLI or
OpenAI-/Anthropic-compatible HTTP APIs.

The performance numbers in this README were **measured with this build** on a
physical RTX 4090 (section [Measured performance — this build](#measured-performance--this-build)).
They are not upstream numbers.

---

## Project Lineage & Credits

This branch stands on the work of the whole NInfer Windows ecosystem. With
gratitude to all of them — in lineage order:

| Contributor | Repository | Contribution |
|---|---|---|
| **Neroued** | [Neroued/ninfer](https://github.com/Neroued/ninfer) | Canonical upstream: C++20/CUDA architecture, DFlash2, ReplaySSM, Paged KV Cache |
| **UDPSendToFailed** | [UDPSendToFailed/ninfer-4090](https://github.com/UDPSendToFailed/ninfer-4090) | **Creator of the original RTX 4090 fork**; pioneer of the WDDM evictable-budget bypass on Windows WDDM and of E8 lattice (Conway-Sloane) geometric quantization, `rk4v4-e8` |
| **sergiuszm** | [sergiuszm/ninfer-4090](https://github.com/sergiuszm/ninfer-4090) | Ada Lovelace `sm_89` kernel optimizations, `rk4v4-e8` adaptation, GDN cooperative-launch fix |
| **natpate** | [natpate/ninfer-windows](https://github.com/natpate/ninfer-windows) | Base Win32/MSVC portability layer, unbuffered asynchronous I/O (`OVERLAPPED`), initial Windows scripts |
| **headpiece747** | [headpiece747/ninfer-5090-windows](https://github.com/headpiece747/ninfer-5090-windows) | Native Windows MSVC compilation base from which this branch descends |
| **Don-Chad** | [Don-Chad/ninfer-3090](https://github.com/Don-Chad/ninfer-3090) | Pioneering Ampere work and early compatibility bridges |

Model foundations: **Qwen Team (Alibaba Cloud)** for the foundational model
architectures, **unsloth** for the NVFP4 quantizations, and **z-lab** for the
DFlash companion weights.

This branch would not exist without that work. See [NOTICE](NOTICE) for the
full legal attribution (Apache-2.0 §4) and third-party details.

---

## Relationship to Upstream (v1.0.7)

This branch tracks upstream `b88c0f6f` (v1.0.7: 7 commits post-v1.0.6 —
MoE pipeline/prefetch/L2 ×3, NVFP4 W4A4 TMA, open-addressed BPE table,
unicode NFC-skip, host-arena fix) plus the sm_89 layer, and the post-merge
correctness work of 2026-09-08 (int4-KV accumulator fix `6c4f5a10`,
small-T T=7/8 port `f7cef9e9`+`486f647d`).

### Shared with upstream

- High-performance C++20/CUDA core and 1:1 compatibility with `.ninfer` artifacts.
- MTP3, DFlash2 (`--spec dflash2 --draft-tokens 7`) and DFlash legacy
  (`K=1..15`) speculative decoding, with transactional ReplaySSM for linear
  GDN states.
- HTTP APIs compatible with OpenAI Chat Completions / Responses and Anthropic
  Messages, including streaming, tools, and token counting.
- Low-latency prefix caching with paged Device/Host KV and State retention.

### Added by this fork

- **Native Windows 11 compilation**: CMake + MSVC 2022 + Ninja + CUDA 13.x —
  no WSL2, no virtualization overhead (`build_windows.bat`, `build_v1.0.7.bat`).
- **WDDM bypass (`--wddm-evictable-budget`)**: D3D12/DXGI residency lock that
  budgets runtime memory against total VRAM instead of the WDDM process
  budget, recovering 1.0–1.5 GB of physically retained VRAM (see
  [Windows WDDM note](#windows-wddm-and-dedicated-gpus)). Concept pioneered
  in [UDPSendToFailed/ninfer-4090](https://github.com/UDPSendToFailed/ninfer-4090).
- **Ada Lovelace adaptations (sm_89 only)**:
  - Kernels adapted to the **48 KiB static shared-memory** limit (static
    schedules ≤48 KiB; dynamic `extern __shared__` with 101,376 B opt-in for
    larger tiles).
  - Integration of **`rk4v4-e8`** (real 4-bit quantization over Conway-Sloane
    E8 lattices) as a KV cache storage.
  - MTP3 profile on Qwen3.6-35B-A3B.

### Verified in v1.0.6 (this branch)

- int4-KV correctness: 27B +6.8% vs v1.0.5 (119.4 tok/s, A/B on this
  hardware, commit `6c4f5a10`), outputs coherent across all int4 KV storages.
- Test suite `ninfer_softmax_attention_test --dflash2-only`: 100% pass on
  bf16/fp8/nvfp4/k8v4 (widths 2..16); the pre-port baseline crashed on W=7.
- **DFlash2 end-to-end on sm_89**: 27B + dflash2 (7 draft tokens) measured at
  104.1 tok/s decode, 28.5% draft acceptance — the e2e item pending since the
  v1.0.6 port is now closed (see
  [Measured performance — this build](#measured-performance--this-build)).
- 260,032-token `rk4v4-e8` KV pool at C=4 with the WDDM budget, 96% of the
  24 GB card resident (measured, not estimated).
- **v1.0.7 test suite on Windows (2026-09-09)**: 103/104 green — 7 skipped
  by-design (real-data + sm_89-only cases), 1 documented pre-existing
  borderline (gdn_gating_proj T=4097, deterministic), 2 excluded on Windows
  (BEX64 0xC0000409 in the MSVC test binaries — not the engine: the v1.0.7
  server with real production data (150k-merge tokenizer, 260k profile)
  boots and serves clean, verified with a :8091 smoke).

Details and A/B measurements: [PORT_v1.0.6.md](PORT_v1.0.6.md).

---

## Windows WDDM and dedicated GPUs

**If your GPU is dedicated, enable `--wddm-evictable-budget` to use its VRAM
to the maximum.** On Windows, the WDDM driver model gives every process a
memory *budget* that is a fraction of total VRAM (the OS holds back the rest
for the display compositor and TDR recovery), and a process that exceeds its
budget gets evicted or fails to commit. NInfer on Windows can instead take a
D3D12/DXGI residency lock and budget against **total VRAM**:

- With the flag, this build ran the 35B-A3B profile with **23,651 MiB
  resident of 24,564 MiB (96%)** — 20.6 GiB weights + a 260,032-token
  `rk4v4-e8` KV pool + 8 GiB pinned host KV, at C=4. Without the flag the
  same configuration does not start on a 24 GB card.
- The flag is safe: if a real GPU memory pressure event happens (e.g. a
  fullscreen game, another CUDA process), WDDM still evicts safely — the
  budget just moves from "a fraction of VRAM" to "VRAM minus the hard
  reserves".
- If you still cannot start the server, lower `--max-context` /
  `--kv-capacity` (or use `--kv-capacity auto`) until startup fits.

The flag is a no-op safety net on multi-GPU systems: pair it with
`CUDA_VISIBLE_DEVICES=<index>` to pin the engine to your card.

---

## Measured performance — this build

Measured **2026-09-08 on a physical RTX 4090 (24 GB, `sm_89`)** with the
pre-compiled binary of this branch, `--wddm-evictable-budget` enabled, single
stream, temperature 0.7. Prefill prompts are deterministic (~12.7k and
~56.3k tokens); decode is one 2,048-token free generation. Timings are the
ones the server itself reports (`prompt_per_second`,
`predicted_per_second`); VRAM is `nvidia-smi` on the 4090.

| Profile | Weights | KV pool (resolved) | Prefill 12.7k tok | Prefill 56.3k tok | Decode 2048 tok | Draft acceptance | VRAM peak |
|---|---:|---:|---:|---:|---:|---:|---:|
| Qwen3.6-35B-A3B — `rk4v4-e8`, MTP3 d3, C=4, 260k ctx | 20.6 GiB | 260,032 tok (explicit) | **10,916 tok/s** (TTFT 1.2 s) | **9,745 tok/s** (TTFT 5.8 s) | **391.4 tok/s** | 52.8 % (1,254/2,377) | 23,651 MiB (96 %) |
| Qwen3.8-27B — `rk4v4-e8`, MTP3 d3, C=2, 131k ctx | 16.7 GiB | 262,144 tok (auto) | **2,143 tok/s** (TTFT 6.0 s) | **1,910 tok/s** (TTFT 29.5 s) | **97.8 tok/s** | 37.7 % (1,086/2,880) | 23,001 MiB (94 %) |
| Qwen3.8-27B DFlash2 — `rk4v4-e8`, dflash2 d7, C=2, 131k ctx | 18.3 GiB | 138,752 tok (auto) | **2,079 tok/s** (TTFT 6.2 s) | **1,857 tok/s** (TTFT 30.4 s) | **104.1 tok/s** | 28.5 % (1,362/4,780, 7 tok) | 22,497 MiB (92 %) |

Engine startup (weights load + CUDA graphs): 10.5 s / 9.2 s / 10.1 s
respectively.

Reading the table:

- **35B-A3B vs 27B**: Qwen3.6-35B-A3B is a MoE with ~3B active parameters, so
  on the same 4090 it prefills ~5× and decodes ~4× faster than the dense
  Qwen3.8-27B. Pick it when your workload fits a single 24 GB card.
- **DFlash2 vs MTP3 on 27B**: 104.1 vs 97.8 tok/s (+6.6%). DFlash2 (7-token
  drafts, 28.5 % per-draft acceptance) beats MTP3 (3-token drafts, 37.7 %)
  on this hardware — and this is the first end-to-end DFlash2 measurement on
  `sm_89` (the item left open by the v1.0.6 port).
- **v1.0.5 → v1.0.6 (A/B on this 4090, 27B, e8 KV)**: 111.8 → 119.4 tok/s
  (**+6.8 %**), entirely from the int4-KV accumulator fix `6c4f5a10`.
- **`--kv-capacity auto`** resolved 262,144 tokens for 27B and 138,752 for
  27B-DFlash2 on 24 GB — DFlash2 keeps more draft state, hence the smaller
  pool. All of this is only possible with the WDDM budget; without the flag
  none of the three profiles would start at these capacities.

All model artifacts are published by Neroued. The base
[`qwen3_8_27b.ninfer`](https://huggingface.co/neroued/Qwen3.8-27B-NInfer)
artifact used above is public and works with `--kv-dtype rk4v4-e8`
(runtime KV quantization). The DFlash2 artifact
(`qwen3_8_27b_dflash2.ninfer`) is the same public base weights with the
DFlash companion merged in via the upstream converter pipeline; as of
2026-09-08 the merged artifact is not yet published in Neroued's public
HuggingFace repos (verified across all of his public NInfer repos).

---

## Comparison with the upstream repository

The upstream project publishes RTX **5090** reference numbers
(docs/performance, v1.0.6, revision `487f8977`, INT8 group-64 KV, auto
capacity). Our build is the same engine core + the sm_89/WDDM layer above, so
the comparison below is *our measured 4090 numbers vs upstream's published
5090 numbers*:

| Metric (single stream) | Upstream 5090 (published) | This build — 4090 (measured) | Ratio |
|---|---:|---:|---:|
| 35B-A3B prefill ~8k tok (INT8 g64 KV) | 17,705 tok/s | 10,916 tok/s (12.7k tok, `rk4v4-e8`) | **62 %** |
| 35B-A3B MTP3 decode C1 | 642.5 tok/s (68.6 % accept) | 391.4 tok/s (52.8 % accept) | **61 %** |
| 27B prefill ~8k tok (INT8 g64 KV) | 3,275 tok/s (Qwen3.8-27B g64) | 2,143 tok/s (12.8k tok, `rk4v4-e8`) | **65 %** |
| 27B MTP3 decode (Qwen3.8-27B g64, structured) | 224.4 tok/s | 97.8 tok/s (free generation, 37.7 % accept) | 44 % |

Honest caveats — the ratio is *not* a pure port-quality number:

1. **Hardware**: Ada Lovelace `sm_89` (24 GB) vs Blackwell `sm_120a` (32 GB).
   60–65 % of the 5090 prefill rate on the 4090 is exactly what the
   generation gap implies; the port itself adds no measurable overhead.
2. **KV dtype**: upstream published tables use INT8 group-64; our runs use
   `rk4v4-e8` (E8-lattice 4-bit), which trades a little accuracy for
   ~2× KV capacity.
3. **Artifacts & acceptance**: draft acceptance depends on the MTP/dflash2
   head baked into the *artifact* and on the prompt content, not on the
   runtime. Our runs used locally quantized artifacts (35B-A3B v2; 27B +
   DFlash2) on free-form generation, while the upstream rows use the public
   artifacts (and, for the 27B decode row, a structured-output scenario).
   That gap is why the decode ratio reads lower than the prefill ratio.
4. **Concurrency**: upstream's C4 35B number (1,213.5 tok/s) is *aggregate*
   over four concurrent streams; our 391.4 tok/s is a single stream on a
   C=4 server (no batching benefit with one request).

Within the *same* hardware, the port's effect is measured separately: the
v1.0.5 → v1.0.6 A/B on this 4090 is **+6.8 %** (int4-KV fix).

---

## Running the server

### Generic startup (shipped as `start_4090.bat`)

Minimal configuration — adjust `--max-context`, `--kv-capacity` and
`--max-concurrency` to your VRAM and workload:

```bat
@echo off
set CUDA_VISIBLE_DEVICES=0
ninfer-serve.exe qwen3_6_35b_a3b.ninfer ^
 --host 127.0.0.1 --port 8080 ^
 --max-context 131072 --kv-capacity auto --kv-dtype rk4v4-e8 ^
 --wddm-evictable-budget --max-concurrency 2 --device-state-slots 2 ^
 --spec mtp --draft-tokens 3 --lm-head-draft ^
 --prefill-chunk 2048
pause
```

### Flag notes

- `--kv-dtype rk4v4-e8` is the E8-lattice 4-bit KV storage (sm_89 branch).
  It is a **runtime** KV quantization: it works with the public
  `qwen3_6_35b_a3b.ninfer` artifact. `bf16`/`int8`/`fp8` are also accepted.
- `--wddm-evictable-budget` — see [Windows WDDM note](#windows-wddm-and-dedicated-gpus).
- `--kv-capacity auto` resolves the largest pool that fits after weights;
  explicit values are fixed for the process lifetime.
- `--spec mtp --draft-tokens 3` (MTP3) or `--spec dflash2 --draft-tokens 7`
  (DFlash2, needs the DFlash2 companion artifact).
- `--max-concurrency` / `--device-state-slots`: one state slot per active
  request; keep them equal for the simplest scheduling.
- Multi-GPU: set `CUDA_VISIBLE_DEVICES` to the index of *your* GPU as seen by
  CUDA. Note that CUDA's enumeration order can differ from `nvidia-smi`'s
  order on multi-GPU systems — verify with a short probe run or by watching
  which card's VRAM moves.

### Verified 260k profile (35B-A3B, this hardware)

The table row that uses 96 % of the 24 GB card:

```bat
ninfer-serve.exe qwen3_6_35b_a3b.ninfer ^
 --host 127.0.0.1 --port 8080 ^
 --max-context 260000 --kv-capacity 260000 --kv-dtype rk4v4-e8 ^
 --wddm-evictable-budget --max-concurrency 4 --device-state-slots 4 ^
 --spec mtp --draft-tokens 3 --lm-head-draft --prefill-chunk 2048
```

---

## Supported Models

Primary target:

| Model | Weights | Artifact | Download and model card |
|---|---|---|---|
| Qwen3.6-35B-A3B | `groupwise-int` | `qwen3_6_35b_a3b.ninfer` | [Qwen3.6-35B-A3B](https://huggingface.co/neroued/Qwen3.6-35B-A3B-NInfer) |

Also verified on this branch (measured above). Model artifacts:
**Neroued** (NInfer checkpoints on HuggingFace).

| Model | Artifact | Download |
|---|---|---|
| Qwen3.8-27B | `qwen3_8_27b.ninfer` (`--kv-dtype rk4v4-e8`, MTP3) | [Qwen3.8-27B-NInfer](https://huggingface.co/neroued/Qwen3.8-27B-NInfer) |
| Qwen3.8-27B DFlash2 | `qwen3_8_27b_dflash2.ninfer` (dflash2, 7 drafts) | the public artifact above + DFlash companion, merged with the upstream converter pipeline; the merged artifact is not yet on Neroued's public HF (2026-09-08) |

---

## Requirements

- 64-bit Windows 11 (Native, **no WSL2 required**)
- NVIDIA GeForce RTX 4090 (`sm_89`)
- NVIDIA driver with CUDA 13.x support (pre-compiled ZIP)
- Microsoft Visual C++ Redistributable 2015–2022 (x64)
- Source builds only: Visual Studio 2022 BuildTools, CUDA 13.3, CMake 3.28+, Ninja

---

## Installation (Pre-compiled)

**Download the [ninfer-4090-windows-v1.0.6.zip](https://github.com/Ambolio/ninfer-windows/releases/download/v1.0.6-windows/ninfer-4090-windows-v1.0.6.zip) from the [v1.0.6-windows release](https://github.com/Ambolio/ninfer-windows/releases/tag/v1.0.6-windows).**

The ZIP contains `ninfer-serve.exe` with its runtime DLLs (FFmpeg), a generic
`start_4090.bat`, a `download_model.bat`, and a `LEEME.txt` with instructions
and model links.

1. Extract the ZIP to a folder.
2. Run `download_model.bat` to download the `qwen3_6_35b_a3b.ninfer` model
   file (or download manually from
   [HuggingFace](https://huggingface.co/neroued/Qwen3.6-35B-A3B-NInfer/resolve/main/qwen3_6_35b_a3b.ninfer)).
3. Double-click `start_4090.bat` to launch the server.
4. Point any OpenAI-compatible client at `http://127.0.0.1:8080/v1`.

---

## Building from Source (For Developers)

### 1. Build Automatically

```cmd
build_v1.0.6.bat
```

Self-contained: sm_89, vision, Release. Needs this tree + MSVC BuildTools +
CUDA 13.3 + Ninja. Pass an alternative build directory as the first argument.

### 2. Manual CMake Build

Open the **x64 Native Tools Command Prompt** and run:

```cmd
cmake -B build -S . -G Ninja -DCMAKE_CUDA_ARCHITECTURES=89 -DNINFER_ENABLE_AVX2=ON -DNINFER_BUILD_MEDIA_ACQUIRE=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j 32
```

---

## Capabilities and limits

All registered model IDs support:

- text generation with thinking and non-thinking prompt modes;
- image, multi-image, video, and mixed multimodal messages;
- chunked prefill, exact-batch CUDA Graph decode, and startup-bounded batched decode;
- MTP3 speculative decoding with draft windows from one to five, DFlash2
  (`--spec dflash2 --draft-tokens 7`, verified e2e on this branch), and DFlash
  legacy (`K=1..15`) on the 35B-A3B target;
- BF16, INT8, FP8, and the sm_89-only `rk4v4`/`rk4v4-e8` lattice KV storage;
- offline causal-perplexity scoring;
- private and shared exact-prefix reuse with Device/Host State and KV retention;
- model-aware sampling defaults and explicit sampler overrides;
- OpenAI Responses Core, OpenAI Chat Completions, and Anthropic Messages,
  including streaming, tools, local response state, token counting, and usage
  accounting.

The product boundary remains intentionally small:

- one RTX 4090 and one resident model per Engine;
- a startup-fixed capacity of one to eight active requests with bounded FIFO ingress;
- no request preemption, priority/QoS, active-request swapping, weight offload,
  multi-GPU, or distributed serving;
- one shared startup-fixed KV pool across active requests and retained prefixes;
- no runtime model discovery or unregistered checkpoint fallback;
- parsed tool calls are returned to the client; NInfer does not execute tools;
- the in-tree C++ headers are not distributed as an installed SDK.

`--max-context` is each sequence's logical limit. `--kv-capacity` sizes the
shared Main Text KV pool used by active requests and retained prefixes; `auto`
resolves the largest legal capacity at startup from the memory remaining after
weights. Explicit capacities remain fixed for the process lifetime.

---

## Documentation

- [Documentation index](docs/README.md)
- [CLI](docs/cli.md)
- [HTTP serving](docs/serving.md)
- [Performance](docs/performance.md)
- [Perplexity evaluation](docs/perplexity.md)
- [Port notes v1.0.6 (sm_89 decisions, verification)](PORT_v1.0.6.md)
- [Contributing](CONTRIBUTING.md)

Run the relevant `--help` for the exact current option contract.

## Support

NInfer is a personal project that Neroued develops out of interest. If you find
it useful and would like to support its continued development, you can
[support the project on Ko-fi](https://ko-fi.com/neroued).

Support is entirely voluntary. It is not a purchase or investment and does not
come with financial returns, promised services or features, or a role in
project decisions.

---

## License & Attribution

This project is licensed under the [Apache License 2.0](LICENSE).

This repository is a Windows MSVC adaptation of the upstream
[Neroued/ninfer](https://github.com/Neroued/ninfer) project, originally
authored by **Neroued** and licensed under the Apache License 2.0. In
accordance with Apache License 2.0 Section 4, all original attribution and
copyright notices are retained; the lineage credits above and the
[NOTICE](NOTICE) file are part of the distribution.

The published artifacts are derived from
[Qwen/Qwen3.6-35B-A3B](https://huggingface.co/Qwen/Qwen3.6-35B-A3B) and the
Qwen 3.8 family. NVFP4 quantizations: [unsloth](https://huggingface.co/unsloth).
DFlash companion weights: [z-lab](https://huggingface.co/z-lab). These source
repositories are distributed under their own licenses. Vendored dependencies
retain their own license files under `third_party/`.

**Third-party binary distribution.** The pre-compiled ZIP packages include
FFmpeg shared libraries (avcodec, avformat, avutil, swresample, swscale) from
the BtbN `ffmpeg-master-latest-win64-gpl-shared` build, distributed under
GPL v2 or later; the full license text ships as `LICENSE-FFMPEG.txt` in the
ZIP and in the repository root. The corresponding source is the FFmpeg
source tree of that build (https://ffmpeg.org,
https://github.com/BtbN/FFmpeg-Builds). NVIDIA, CUDA, and RTX are trademarks
of NVIDIA Corporation. Model weights are **not** redistributed with this
project: users download them directly from HuggingFace under the model
owners' own licenses.

**Disclaimer.** This software is provided "as is" (AS IS), without warranty
of any kind, express or implied. The authors are not liable for hardware
damage, system instability, data loss, or overheating resulting from the use
of these binaries or configurations, including configurations that run the
GPU at or near its full memory and power envelope. You use this software at
your own responsibility.
