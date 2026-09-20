# CHANGELOG_DEV

## 2026-09-21 — RewardTrace dylib initial implementation

### Added

- `src/RewardTrace.mm`: version-locked runtime tracer.
- `include/RewardTraceOffsets.h`: validated RVA table and exact target identity.
- `Makefile`: arm64 iPhoneOS dylib build + verification.
- `.github/workflows/build.yml`: macOS arm64 CI build and artifact upload.
- `scripts/check_offsets.py`: aligned/unique RVA consistency guard.
- Project roadmap/handoff/state/known-issues files.

### Behavioral constraints

- No forced `Action<bool>(true)`.
- No mutation of `hasReceivedReward`.
- No RPC payload/response modification.
- No fabricated reward/state.
- Original hooked functions are invoked once with original arguments.
- UUID mismatch fails closed before hooks are installed.

### Static verification

- Uploaded target UnityFramework SHA-256: `3af327d13bd102a6ad5938c23272e601626657e6b463df455354a44aae988057`.
- Target Mach-O UUID: `589A1CB1-1AC9-3E73-943A-B45C315C17FC`.
- IL2CPP metadata v39.
- IL2CPP output validator passed with 508,002 mapped methods.
- 28 hook RVAs passed unique + ARM64 4-byte alignment guard.
- Local strict C++17 syntax audit passed.

### CI build result

- Verified source commit: `afa6f9a7d5d038d45e7f996752cb895bf20e4828`.
- Actions run: `35541086512` — **success**.
- Job: `106158753113` — **success**.
- Runner: macOS 15.7.9 arm64.
- Xcode: 16.4 (16F6).
- iPhoneOS SDK: 18.5.
- Apple Clang: 17.0.0.
- Output: thin arm64 Mach-O DYLIB, ad-hoc signed.
- RewardTrace.dylib SHA-256: `53293b7a6ccd17028a9134f8b82b660b16784e1d4ec45d9e02c5336632b344a8`.
- Artifact ID: `10614881595`.
- Artifact ZIP SHA-256: `dd081260211bfecc776684feba6d7691fe5c828e97225a6abb8cc87569e34616`.

### Runtime status

- iPhone injection: **not run**.
- Runtime hook ABI: **not device-verified**.
- Server reward response: **not device-verified**.
- Final reward persistence: **not device-verified**.
- Regression: **not run**.
