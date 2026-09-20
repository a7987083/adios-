# KNOWN_ISSUES

## KI-001 — Supplied IL2CPP dump is not fully validator-complete
- Status: Open
- Evidence: supplied package contains UnityFramework, global-metadata.dat, dump.cs only; no script.json / validator manifest.
- Impact: RVA mappings are structurally plausible but cannot yet be treated as fully validated dumper output.
- Next validation: semantic spot-check selected methods against arm64 disassembly and executable ranges.

## KI-002 — Rewarded ad correctness not yet runtime-proven
- Status: Open
- Evidence: AdsController -> AdManager -> MaxMediation rewarded path exists statically, including received-reward and hidden/display-failed callbacks.
- Risk: duplicate callback, close-before-reward, timeout, background/resume, or retry races can only be proven with runtime callback ordering.
- Next validation: add callback tracing keyed by a per-show process identifier and verify exactly-once reward delivery.

## KI-003 — ATT/privacy initialization order not yet proven
- Status: Open
- Evidence: AppTrackingTransparency is linked and ATT-related strings exist, but no Info.plist or app lifecycle source was supplied.
- Risk: SDK initialization or ad request may run before privacy state is finalized.
- Next validation: inspect IPA Info.plist / initialization entrypoint or source project when available.

## KI-004 — Frida/Substrate strings present but not established as loaded dependencies
- Status: Investigating
- Evidence: UnityFramework strings include fridagadget and /Library/MobileSubstrate/DynamicLibraries/FridaGadget.dylib; Mach-O dylib load-command audit did not establish FridaGadget as a direct LC_LOAD_DYLIB dependency.
- Rule: do not classify as injected solely from strings.
- Next validation: locate cross-references / code paths or inspect containing IPA load graph/runtime image list.
