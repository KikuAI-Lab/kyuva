# Findings

Status: BLOCKED.

1. **BLOCKER — mandatory physical acceptance is unproven (AC1, AC4, AC8).**

   `.agent/tasks/issue-2-nearby-control/spec.md:34-37,48-51,69-73`
   requires a fresh physical Mac↔iPhone AirDrop/Files pass, physical
   iPhone→Mac playback controls and acknowledgements, real prompt
   viewport/idle-sleep checks, and iPhone→Watch regression. The current task
   artifacts have no sanitized device receipt or physical readback. Static
   source review, loopback TLS, and unsigned Release builds do not prove those
   behaviors.
   These criteria must remain BLOCKED/UNKNOWN until the physical matrix is
   run without credentials or provider mutations.

2. **HIGH — real Bonjour/browser and macOS Local Network consent are unverified
   (AC2).**

   `Tests/KyuvaTests/KyuvaCoreTests.swift:417-519` proves direct
   `NWListener`/`NWConnection` TLS-PSK loopback only. It does not exercise
   `Kyuva/Platform/LocalRemoteServer.swift:83-163` with
   `KyuvaMobile/Connectivity/MacRemoteClient.swift:117-247` through `NWBrowser`,
   service registration, or the physical consent path. The implementation's
   authorization probe and 20-second registration timeout therefore remain
   unobserved on the physical Mac. The final simulator did discover a
   host-advertised service, but that is supporting evidence only and does not
   close the physical gate. This is a release gate, not proof of a code failure.

## Verified clean in this review

- `swift test --scratch-path <temporary-root>/swiftpm`: 31 tests passed, 0
  failures, including exact atomic export-file creation.
- Fresh unsigned Release builds passed for macOS universal, iOS, and watchOS;
  fresh signed macOS and iOS builds (with embedded Watch) passed strict deep
  signature verification.
- `ScriptTextTransfer` now delegates export creation to the tested
  `ScriptTextFile.writeExport` boundary. The actual iPhone ShareLink → Save to
  Files → fileImporter system round-trip passed with the committed exact
  artifact and screenshots. The former F-003 local integration gap is closed;
  AC1 remains blocked only by its explicit physical AirDrop/Files requirement.
- Built product inspection passed for version `1.0` build `2`, embedded Watch
  app, `_kyuva._tcp`, local-network usage strings, and the intended Mac
  sandbox capabilities.
- No plaintext fallback, MultipeerConnectivity, backend, third-party package,
  script-content payload, private Bonjour metadata, or prohibited capability
  was found in the changed slice.

No implementation-level FAIL was found in static review; the ship decision is
blocked by the missing physical and integration evidence above.
