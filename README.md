# RewardTrace.dylib

Version-locked, read-only runtime tracer for the authorized Random Dice 2 IL2CPP test build analyzed in this project.

## Scope

The dylib observes:

`button click -> rewarded-ad flow -> business Action<bool> -> RPC state machine -> server-result pipeline -> success callback -> selected client state/UI refresh`

It does **not** force ad success, change callback booleans, patch reward state, modify RPC requests/responses, or fabricate rewards.

## Exact target build

- Architecture: arm64 Mach-O `UnityFramework`
- Expected Mach-O UUID: `589A1CB1-1AC9-3E73-943A-B45C315C17FC`
- Expected SHA-256: `3af327d13bd102a6ad5938c23272e601626657e6b463df455354a44aae988057`
- Address semantics: validated IL2CPP preferred VA/RVA; this build has `__TEXT vmaddr = 0`, so runtime address is `dyld slide + RVA`.

The UUID is checked before any hook is installed; mismatch fails closed.

## Build

On macOS with Xcode/iPhoneOS SDK:

```bash
make verify
```

Output: `build/RewardTrace.dylib`.

GitHub Actions also builds an ad-hoc-signed arm64 dylib and uploads it as a workflow artifact.

## Runtime dependency

`MSHookFunction` is resolved dynamically. The injection environment must already provide a Substrate-compatible API (for example ElleKit). If absent, no hook is installed.

## Logs

Filter device logs for `RewardTrace` / `[RewardTrace]`. A normal daily-free-package path should include click, ad show, ReceivedReward, Hidden, AdsController result, business callback, RPC MoveNext, server result, success callback, and the resulting data/UI change.

Final acceptance requires the expected reward/state to remain changed after refreshing or reloading server-backed data.

## Versioning

Every RVA is build-specific. After an app update, re-run Mach-O/IL2CPP validation and update UUID + offsets together; never reuse old offsets blindly.
