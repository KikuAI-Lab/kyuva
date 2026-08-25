# QA matrix — 2026-08-25

| Criterion | State | Evidence / remaining proof |
|---|---|---|
| AC1 — standard local transfer | UNKNOWN physical | iPhone simulator `.txt` round-trip passed; source has bounded UTF-8 import and system share. Physical Mac ↔ iPhone AirDrop/Files pass is still required. |
| AC2 — explicit encrypted pairing | PARTIAL | Matching/mismatched TLS-PSK tests pass, 80-bit generation is tested, discovery is user-scoped, and simulator failure is visible. Real Mac Bonjour consent and physical pairing are still unproved. |
| AC3 — bounded remote protocol | PASS | Five commands only, 4 KiB frames, strict version/keys/sequence/replay checks, one-client server, and 30-test suite pass. |
| AC4 — usable Mac remote | UNKNOWN physical | Final simulator discovers the service and shows bounded connection failure; physical title/state/pace/progress and five-command acknowledgement are still required. |
| AC5 — configuration and privacy truth | PASS | Product/plist/entitlement/privacy/dependency/capability scans match the contract. |
| AC6 — release identity | PASS | All source products are `1.0 (2)`; App Store Connect remained on uploaded macOS `1.0 (1)`. |
| AC7 — deterministic proof | PASS local | 30 tests plus macOS universal, iOS, watchOS Release and iPhone simulator Debug builds pass; final independent verifier verdict is separate. |
| AC8 — physical regression proof | UNKNOWN | Physical iPhone and Watch were unavailable at final readback. Simulator Watch remote passed, but does not substitute for the physical matrix. |
| AC9 — owner gates | PASS | No build upload, App Review action, accessibility publication, credential, provider, or irreversible action occurred. |

Overall release decision for build `2`: **HOLD** until AC1, AC2, AC4, and AC8
receive physical evidence and macOS Local Network consent permits a real
Bonjour session. The already uploaded build `1` is unchanged.
