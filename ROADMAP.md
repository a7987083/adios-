# ROADMAP

## Phase 1 — RewardTrace dylib

- [x] Lock exact UnityFramework identity (SHA-256 + Mach-O UUID).
- [x] Map four business button chains to validated IL2CPP RVAs.
- [x] Implement fail-closed runtime UUID check.
- [x] Implement read-only trace hooks without changing callback/RPC data.
- [x] Add arm64 iOS dylib CI build.
- [ ] Confirm GitHub Actions build succeeds.
- [ ] Download artifact and record artifact SHA-256.
- [ ] Inject on authorized iPhone test environment.
- [ ] Exercise all four buttons and capture logs.
- [ ] Verify server-backed reward/state persists after refresh/relaunch.

## Next Task

Run GitHub Actions on `reward-trace-dylib`; if it fails, fix the first real compile/link error, then publish the successful artifact details.
