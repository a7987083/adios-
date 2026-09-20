# CHANGELOG_DEV

## 2026-09-21

### Analysis baseline
- Created branch `work/randomdice2-ad-audit` from `a997f854209de8375d4606fa611e0649d73e0a97`.
- Recorded SHA-256 hashes for supplied RandomDice2 analysis artifacts.
- Confirmed target is iOS arm64 Unity IL2CPP with metadata version 39.
- Confirmed ad path: `AdsController` -> `AdManager/IAdMediation` -> `MaxMediation` -> AppLovin MAX.
- Confirmed rewarded/interstitial/banner support and ad revenue/event callbacks.
- Confirmed `AppLovinSDK.framework` as a direct Mach-O dependency; ATT/AdSupport are weak-linked.
- Recorded unresolved runtime/privacy/dump-validation risks in `KNOWN_ISSUES.md`.

### Verification state
- Modified repository docs: yes.
- Source code modified: no.
- Build: not attempted.
- CI: not configured.
- Runtime: not run.
- Device validation: not performed.
- Regression validation: not performed.
