# Android Dual-Screen Implementation Ledger

The authoritative specification for this port is the preserved one-time Dusklight
implementation checkpoint. This ledger maps that contract to implementation stages;
it does not replace or weaken the checkpoint.

Authorization: `already_authorized`

## Requirements

| ID | Requirement | Stage | Status | Evidence |
| --- | --- | --- | --- | --- |
| R1 | Use the newest normal official stable release as the exact base and the newest normal dual-screen release as the feature reference. | 1 | satisfied | Official `v1.4.1` at `f5642f307384bd4b7b7a09f690e391152445c815`; reference `v1.4.1-ds-2.7` at `7856a9262449ed3a085623775a153ec1d230ef2a`, revalidated through authenticated GitHub APIs on 2026-09-08. |
| R2 | Keep the Android platform layer and dual-screen feature layer as distinct reviewable commits on a clean official base. | 2 | satisfied | Android platform commit `6040dde36eb2063c0e796cf0eb296e4ce1766914`; adapted dual-screen layer remains the next distinct commit. |
| R3 | Preserve official stable behavior plus complete Android and reference dual-screen feature/UX parity, including immersive display behavior, display-specific overlays, settings, controller support, and saves. | 2 | satisfied | Source contracts, guide/version unit tests, stable-API reconciliation, arm64 native compilation, Java compilation, and release packaging passed. |
| R4 | Document provenance, deliberate deviations, unofficial status, accepted user-owned USA/EUR ISO/RVZ input, and absence of bundled copyrighted game data. | 3 | satisfied | `README.md` and `docs/android/PROVENANCE.md` record the complete boundary and migration note. |
| R5 | Use numeric version identity with monotonic versionCode and consistent tag/APK filename; put descriptive Dual Screen wording only in the release title. | 3 | satisfied | `versionName`/tag `1.4.1.1`, `versionCode` `104001001`, and numeric-versioned APK filename verified. |
| R6 | Build and test the release for the exact source-derived ABI set and require 16 KiB alignment for arm64 native entries. | 4 | satisfied | Official/reference production workflows are exactly arm64; release native/Java/lint/Gradle builds passed and all APK/ELF alignment checks passed. |
| R7 | Add a new persistent per-package signer only after signing-worker tests pass; Normalize through the unsigned-input gate and Verify without publishing to H:. | 5 | satisfied | Worker passed 32/32 before and after initialization; policy `dusklight` was normalized and verified without `Publish`. |
| R8 | Verify package/version/ABIs/alignment/signature/signer/SHA-256 and absence of copyrighted or personal payloads, including nested assets. | 5 | satisfied | Candidate is `dev.twilitrealm.dusk`, `1.4.1.1`/`104001001`, arm64, signer `41f77566128bdee40fd94cbac5cdb14fb1c9d7f20cf0b671b511f5247363e863`, SHA-256 `1a314d7feee42e5def8160ed296e4970afd681a55815cf97e21a30f2409214d3`; both verifier paths passed. |
| R9 | Publish only a completely verified main branch and one normal GitHub release with exactly one APK and one checksum sidecar; never overwrite a collision. | 6 | pending | Target repository does not yet exist; creation is deferred until all prepublication gates pass. |
| R10 | Download published assets through the GitHub API, verify them again, and confirm ObtainX discovery. | 6 | pending | Authenticated round-trip pending. |
| R11 | Do not use ADB or control a device; report the one-time reinstall/data-migration implication of the new signer. | 6 | satisfied | No ADB/device action was used; README and provenance record the one-time reinstall requirement. |
| R12 | On verified success, extend the permanent weekly Native Android updater without removing any existing target or rule; on failure, leave it unchanged. | 7 | pending | Updater change is gated on public round-trip success. |
| R13 | Remove attributable temporary/generated artifacts after verification while preserving source, credentials, user data, and known-good releases. | 7 | in_progress | Transactional cleanup inventory started before disk-intensive work. |

## Stages

1. Revalidate provenance and preserve the resume state. Verify R1 and the exact
   checkout/index state without changing the selected base.
2. Reconcile and verify the staged dual-screen layer against R2-R3, resolve only
   evidenced integration defects, and commit it separately.
3. Add durable provenance, user-facing documentation, release metadata, and
   repository verification tooling for R4-R5.
4. Build both source-derived Android ABIs, run contract/unit/Gradle checks, and
   verify R6 before accepting release output.
5. Test the signing worker, establish the package-specific identity, normalize the
   unsigned APK, and run the complete R7-R8 policy verification.
6. Reconcile all requirements, create/push the authorized repository and release,
   then perform the authenticated R9-R11 round trip.
7. With zero blockers and zero tracked deferrals, extend the permanent updater,
   complete R12-R13, and record final evidence.

## Gaps

- Blockers: 0
- Tracked deferrals: 0
