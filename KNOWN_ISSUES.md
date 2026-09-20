# KNOWN_ISSUES

## KI-001 — Hook backend availability

If `MSHookFunction` is not visible through `RTLD_DEFAULT`, RewardTrace installs no hooks and logs the reason. Validate on the intended jailbreak/injection stack before adding any alternative backend ABI.

## KI-002 — Version-specific RVAs

An updated UnityFramework will fail the UUID check. Re-run IL2CPP + ARM64 validation; do not reuse old offsets.

## KI-003 — Managed string helper exports

If `il2cpp_string_length` / `il2cpp_string_chars` are unavailable through `dlsym`, managed strings are logged as object pointers. Control-flow tracing still works.

## KI-004 — Runtime not yet verified

CI compilation will not prove target runtime hook ABI correctness. First iPhone test should use one button at a time and retain crash/syslog evidence if a fault occurs.
