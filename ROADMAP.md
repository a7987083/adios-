# ROADMAP

## Phase 1 — RewardTrace dylib

- [x] Lock exact UnityFramework identity (SHA-256 + Mach-O UUID).
- [x] Map four business button chains to validated IL2CPP RVAs.
- [x] Implement fail-closed runtime UUID check.
- [x] Implement read-only trace hooks without changing callback/RPC data.
- [x] Add arm64 iOS dylib CI build.
- [x] Confirm GitHub Actions build succeeds.
- [x] Download artifact and independently verify artifact + dylib SHA-256.
- [ ] Inject on authorized iPhone test environment.
- [ ] Confirm `MSHookFunction` resolves on the intended injection stack.
- [ ] Exercise all four buttons and capture complete `[RewardTrace]` chains.
- [ ] Verify server-backed reward/state persists after refresh/relaunch.
- [ ] Run regression after all four flows pass.

## Verified build

- Source commit: `afa6f9a7d5d038d45e7f996752cb895bf20e4828`
- Actions run: `35541086512`
- Job: `106158753113`
- Artifact: `10614881595`
- RewardTrace.dylib SHA-256: `53293b7a6ccd17028a9134f8b82b660b16784e1d4ec45d9e02c5336632b344a8`

## Next Task

Inject the verified dylib into the exact UUID-matched target and run one normal reward flow without forcing any result. Capture the full `[RewardTrace]` log and compare the server-backed value before/after refresh.
