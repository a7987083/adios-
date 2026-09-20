# CHANGELOG_DEV

## 2026-09-21 — RewardTrace dylib initial implementation

### Added

- `src/RewardTrace.mm`: version-locked runtime tracer.
- `include/RewardTraceOffsets.h`: validated RVA table and exact target identity.
- `Makefile`: arm64 iPhoneOS dylib build + verification.
- `.github/workflows/build.yml`: CI build and artifact upload.
- `scripts/check_offsets.py`: aligned/unique RVA consistency guard.
- Project roadmap/handoff/state/known-issues files.

### Behavioral constraints

- No forced `Action<bool>(true)`.
- No mutation of `hasReceivedReward`.
- No RPC payload/response modification.
- No fabricated reward/state.
- Original hooked functions are invoked once with original arguments.

### Verification status

- Static implementation is based on the validated uploaded UnityFramework/metadata/dump.
- Local iPhoneOS build: not run on current Linux host.
- GitHub Actions arm64 build: pending initial commit.
- Runtime/iPhone test: pending.
