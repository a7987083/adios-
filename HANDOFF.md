# HANDOFF

## Objective

Trace whether four rewarded-ad business buttons proceed from click through real server-backed success without forcing any success condition.

## Stable evidence baseline

- UnityFramework SHA-256: `3af327d13bd102a6ad5938c23272e601626657e6b463df455354a44aae988057`
- Mach-O UUID: `589A1CB1-1AC9-3E73-943A-B45C315C17FC`
- Architecture: arm64
- `__TEXT vmaddr`: `0`
- IL2CPP metadata: v39
- IL2CPP output validator: passed, 508,002 methods

## Critical flow

1. Button click.
2. `AdsController.<PlayAds_RewardVideo>d__7.MoveNext`.
3. MAX show.
4. MAX `ReceivedReward` sets closure `hasReceivedReward` at `+0x38`.
5. MAX `Hidden` forwards that bool to `Action<bool>`.
6. Business callback continues only when success is true.
7. Per-business RPC async state machine runs.
8. Shared server-result handlers process the response.
9. Business success callback receives the response object.
10. Selected state/UI update executes.

## Hook design

Methods returning `UniTask` are deliberately not hooked because a wrong native value-type return prototype can corrupt the ARM64 ABI. The implementation hooks void/scalar-return clicks, callbacks, async `MoveNext`, server handlers, and success callbacks instead.

The hook backend is resolved with `dlsym(RTLD_DEFAULT, "MSHookFunction")`; no hook library is linked into the product. UUID mismatch fails closed.

The dylib observes only. It does not change callback booleans, `hasReceivedReward`, RPC parameters, responses, reward lists, counts, or UI state.

## Validated response fields

- `BaseResponse.errorCode`: `+0x10`
- `GameResponse.serverResult`: `+0x14`
- `RewardResponse.rewardList`: `+0x28`
- `RewardResponse.updateGoodsDict`: `+0x30`
- Coop tickets `dailyAdsCoopTickets`: `+0x40`
- Daily free pack `dailyFreePackageInfo`: `+0x40`
- Chuseok `freeId/receiveCount/receiveDay`: `+0x40/+0x44/+0x48`
- Coop boost `watchCount/remainCount`: `+0x20/+0x24`

## Verified build

- Source commit: `afa6f9a7d5d038d45e7f996752cb895bf20e4828`
- Actions run: `35541086512`
- Job: `106158753113`
- Build result: success
- Artifact ID: `10614881595`
- Artifact ZIP SHA-256: `dd081260211bfecc776684feba6d7691fe5c828e97225a6abb8cc87569e34616`
- RewardTrace.dylib SHA-256: `53293b7a6ccd17028a9134f8b82b660b16784e1d4ec45d9e02c5336632b344a8`
- Output: Mach-O thin arm64 DYLIB, ad-hoc signed

## Runtime acceptance

Do not mark runtime-verified until the exact target build logs the complete chain and the actual server-backed reward/state remains changed after refresh/relaunch.

Current state: compiled and artifact-verified; not injected, not runtime-verified, not regression-verified.
