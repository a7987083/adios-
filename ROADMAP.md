# ROADMAP

## Phase 1 — Baseline & evidence
- [x] Pin analysis branch and repository baseline.
- [x] Record hashes for supplied UnityFramework / global-metadata.dat / dump.cs.
- [x] Identify engine/runtime and advertising stack.
- [ ] Validate supplied dump output against executable ranges and semantic spot checks.

## Phase 2 — Ad flow audit
- [ ] Reconstruct AdsController -> AdManager/IAdMediation -> MaxMediation call flow.
- [ ] Verify initialization/ATT/privacy ordering.
- [ ] Verify rewarded callback exactly-once semantics and close-before-reward edge cases.
- [ ] Verify load failure retry/backoff and no-ad fallback.
- [ ] Verify interstitial/banner lifecycle and placement/revenue analytics.

## Phase 3 — Implementation
- [ ] Add test harness / instrumentation needed to observe the real callback order.
- [ ] Implement minimal fixes only after root cause is proven.
- [ ] Build/CI validation.
- [ ] Device/runtime regression validation.

## Next Task
Complete static control-flow validation for AdsController and MaxMediation, then define the smallest runtime test harness needed for the remaining unknowns.
