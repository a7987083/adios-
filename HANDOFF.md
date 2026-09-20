# HANDOFF

## Objective

Trace whether four rewarded-ad business buttons proceed from click through real server-backed success without forcing any success condition.

## Stable evidence baseline

- UnityFramework SHA-256: `3af327d13bd102a6ad5938c23272e601626657e6b463df455354a44aae988057`
- Mach-O UUID: `589A1CB1-1AC9-3E73-943A-B45C315C17FC`
- Architecture: arm64
- `__TEXT vmaddr`: `0`
- IL2CPP metadata: v39

The uploaded IL2CPP output validator passed before implementation.

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

## Validated response fields

- `BaseResponse.errorCode`: `+0x10`
- `GameResponse.serverResult`: `+0x14`
- `RewardResponse.rewardList`: `+0x28`
- `RewardResponse.updateGoodsDict`: `+0x30`
- Coop tickets `dailyAdsCoopTickets`: `+0x40`
- Daily free pack `dailyFreePackageInfo`: `+0x40`
- Chuseok `freeId/receiveCount/receiveDay`: `+0x40/+0x44/+0x48`
- Coop boost `watchCount/remainCount`: `+0x20/+0x24`

## Runtime acceptance

Do not mark runtime-verified until the injected dylib logs the complete chain and the actual server-backed reward/state remains changed after refresh/relaunch.
