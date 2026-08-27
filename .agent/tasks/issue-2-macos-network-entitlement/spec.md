# macOS network-server App Review remediation

## Original task

Remediate Apple's automated App Review rejection of Kyuva macOS `1.0 (3)`
under Guideline 2.4.5. Apple detected
`com.apple.security.network.server` and could not identify matching functionality.

## Constraints

- Preserve only functionality and entitlements that are truthful, user-visible,
  and testable in the submitted product.
- Prefer the smallest safe remediation: a factual App Review explanation when
  the entitlement is genuinely required; otherwise remove the unavailable
  feature and entitlement from the first Mac release.
- Keep scripts local. The remote channel may carry only bounded playback state
  and control messages.
- Do not upload or submit an iPhone or Watch build in this task.
- Do not send a reviewer reply, change App Store Connect metadata, upload a new
  binary, or resubmit without explicit current-task owner approval.
- Do not accept new Apple legal terms.

## Acceptance criteria

- **AC1 — Listener necessity:** current source evidence proves whether a
  user-started, user-visible Mac feature creates an `NWListener`, advertises a
  Bonjour service, and accepts incoming local-network connections.
- **AC2 — Minimum entitlements:** every Mac networking entitlement is mapped to
  a concrete production code path; any unnecessary entitlement is removed.
- **AC3 — Review reproducibility:** if the listener remains, the proposed App
  Review response and review notes give exact Mac UI steps and describe what
  data crosses it. If it is removed, they state that build change explicitly.
  Neither path may claim an unavailable public companion app.
- **AC4 — Regression safety:** targeted tests and a fresh macOS Release build
  pass after any source/configuration change; the resulting signed archive's
  entitlements match the accepted decision.
- **AC5 — Honest Store state:** live App Store Connect status and any later
  response, upload, build selection, or submission are recorded separately.

## Non-goals

- Mobile App Store submission or public availability.
- A new networking protocol, backend, account, analytics, or cloud service.
- Feature expansion beyond the rejection remediation.
- Claiming Apple approval or public release before a live readback proves it.

## Verification plan

1. Inspect the entitlements, Mac remote UI, `NWListener` lifecycle, accepted
   connection handling, protocol limits, and mobile discovery/client path.
2. Run the existing core tests and focused source assertions.
3. Choose metadata-only explanation versus binary change from the evidence.
4. If code/config changes, build and inspect a fresh signed archive before any
   upload request.
5. Read App Store Connect after each authorized external action.
