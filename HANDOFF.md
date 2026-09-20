# HANDOFF

## Current context
Authorized test project for auditing and improving the iOS advertising flow of RandomDice2.

## Supplied artifacts
- UnityFramework — iOS arm64 Mach-O, SHA-256 `3af327d13bd102a6ad5938c23272e601626657e6b463df455354a44aae988057`
- global-metadata.dat — IL2CPP metadata v39, SHA-256 `0662f02703ebaf7e2116667ef8245b9e06881b20c12c954a79be4a1605b4e3c5`
- dump.cs — SHA-256 `d2d6902fcf4cb48137ec5d231c67a6d5b046d3d0dd81f9b450037a65317ec4a5`

## Confirmed architecture / ad path
`AdsController` (Assembly-CSharp) -> `Percent.Marketings.PercentAds.AdManager` / `IAdMediation` -> `Percent.Marketings.PercentAds.PercentAdsMax.MaxMediation` -> AppLovin MAX native SDK.

Confirmed formats: rewarded video, interstitial, banner.
Confirmed app placements include `popupstore_daily_ad`, `ticket_coop_daily_ad`, `coop_ad_boost`.

## Important implementation evidence
- `AdsController.Initialize` RVA `0x3616D84`
- `AdsController.LoadAndShowRewardVideo` RVA `0x3616EB8`
- `AdsController.ShowRewardVideo` RVA `0x36171F0`
- `AdsController.LoadRewardVideo` RVA `0x36172D4`
- `MaxMediation` contains independent banner/interstitial/reward ad unit IDs and callback binding.
- AppLovinSDK.framework is a direct Mach-O dependency.
- AppTrackingTransparency.framework and AdSupport.framework are present as weak-linked system dependencies.

## Validation state
- Static identification: complete.
- Dump semantic validation: partial only; no script.json/validation manifest supplied.
- Build: not attempted.
- Runtime/device: not verified.

## Next engineer task
Disassemble and cross-check the rewarded/interstitial state machines, then instrument runtime callback order with per-show IDs. Do not patch offsets until the semantic spot-check is complete.
