# AEROGREEN verification report

Run ID: `20261013-135436`. Time zone: Asia/Saigon, UTC+07:00. Run started on 2026-10-13 at 13:54:36. Command timestamps and immediate native exit codes are in each `.log` header and accompanying `.json` metadata.

## Git and scope

- Workspace: `[workspace]`.
- Original/current branch: `main`; base HEAD: `4e3f66a84032b0b03a19fc5a15ed7a3eebecb325`.
- Initial working tree was clean. No existing user changes were reset, cleaned or stashed.
- No branch change, staging, commit or push was performed, per the overriding section 8 of the request. Changes remain in the working tree.
- Backend ASP.NET Core and both Flutter UI paths are in scope. No firmware/native/E2E, live database, MQTT broker, Docker or production startup.

## Toolchain and environment

Windows x64; PowerShell 5.1.26100.9444; .NET SDK 10.0.401, MSBuild 18.9.11, .NET/ASP.NET runtime 10.0.12; Flutter 3.47.6 and Dart 3.13.5 from the local `.runtime/flutter` SDK.

NuGet restore added test-only Moq 4.20.72 and coverlet.collector 6.0.4. The sandbox initially refused the NuGet connection; restore succeeded outside the sandbox. Flutter package resolution was stale despite cache directories existing. `flutter pub get --directory frontend` resolved the declared dependencies and updated six SDK-constrained lock entries, then exited 1 at Windows plugin symlink setup (Developer Mode unavailable). Unit/widget tests work with the resolved package config and `--no-pub`; Android configuration was not changed. Initial Flutter tool execution also required running outside the sandbox for Windows subprocess access.

`frontend/.env` was absent. A local, ignored file was created with only `BACKEND_BASE_URL=http://127.0.0.1:1`; no secret and no reachable backend. No root `.env`, pgAdmin or Android configuration was changed.

## Baseline and final results

| Check | Baseline | Final | Final native exit |
|---|---|---|---:|
| Backend xUnit | 65 pass, 0 fail, 0 skip | 105 pass, 0 fail, 0 skip | 0 |
| Flutter VM | 110 pass, including 57 placeholders; 2 suite-loading compile errors | 99 pass: 34 unit + 65 widget; 0 fail, 0 skip | 0 |
| Chrome browser-only widget | Not run in baseline | Suite bootstrap failed; 0 case executed | 1 |
| Backend Release build | Not run separately in baseline | Success, 0 warnings/errors | 0 |
| Flutter analyze | 205 issues, primarily unresolved declared packages | No issues found | 0 |

Baseline Flutter compile errors affected `dio_repositories_test.dart` and `phase12_global_states_a11y_test.dart`. They were environmental dependency-resolution failures, not proof of assertion failures. The browser-only file is excluded by its `@TestOn('browser')` annotation from the VM run; it is not counted as a VM skip. Final classifications/counts are derived from Dart runner JSON events, not file count or regex alone. Backend counts are from TRX.

Placeholder assertions: **57 before, 0 after**. The 57 old declarations were consolidated into 20 meaningful production widget cases; unsupported product descriptions were not recreated as artificial assertions. Two schedule tests that tested locally copied validation now call validation shared with the production form. Existing meaningful tests were retained.

## Changes and fixes

1. Added JWT signature/claims/roles/expiry and refresh-value tests using an injected TimeProvider.
2. Added boundary cases for profile, provisioning, alerts, pump, schedules, tickets and admin rules.
3. Extracted the pump endpoint's existing owner predicate and duplicate-payload check for isolated execution tests; the expressions/conditions preserve existing behavior.
4. Injected MQTT client and extracted existing acknowledgment/dispatch-attempt mutations. Tests cover QoS1 publication, contract, disconnected gate, timeout/cancellation and retry marking with a fixed clock.
5. Backend Web SDK content glob was copying nested test build/restore artifacts recursively; exclude `tests/**` from Content/None in the application project. Test project remains independently built.
6. Added fake HTTP/Dio/storage tests. Corrected ApiService refresh success from 201 to the backend's actual 200 response. Login/register now use the existing injected client rather than bypassing it.
7. Guarded Dio refresh endpoint/retried requests against unbounded recursive 401 refresh.
8. Default AuthController now reports restore/logout storage errors in state instead of leaving an unhandled initialization future or permanent loading state.
9. Wi-Fi connection action now invokes the existing simulation, which it previously omitted, leaving the flow stuck until timeout. QR/BLE/Wi-Fi remain simulations, not hardware validation.
10. The default auth page placed full-width social buttons inside an unconstrained Row. The new default app/router widget test detected the infinite-width layout error; bounded Expanded children fix it.
11. Shared Cupertino schedule form validation with tests without changing its current time-window rules.

See `../../unit-test-plan.md` for the module matrix and `../../test-cases.md` for the case inventory.

## Coverage

| Component | Covered / measured lines | Line coverage | Branch coverage |
|---|---:|---:|---:|
| C# application assembly | 263 / 10,932 | 2.41% | 223 / 970 = 22.99% |
| Dart LCOV | 3,613 / 8,109 | 44.56% | Not reported by this LCOV |

C# collector measures `IOTAgriBackend`, excluding the test assembly by collector default. No custom exclusions/thresholds were configured; generated migration/snapshot source remains in the denominator (28 migration classes). Most database-backed endpoints/startup are not executed by this isolated suite. `TokenService`, `DeviceAccess`, `PumpCommandRules` and `PumpDispatchAttempt` report 100% measured line coverage, which does not establish system-level correctness.

Dart coverage is the files recorded by `flutter test --coverage` under the VM suite; it is not a guarantee that every never-loaded library in the repository is included. Browser/firmware/native code is outside this measurement. C# and Dart percentages are not combined. There was no baseline coverage collection, so no coverage improvement delta is claimed.

Artifacts: `final/backend-coverage.cobertura.xml`, `final/frontend-lcov.info`, `final/summary.json`, `final/backend.trx`, `final/frontend-events.jsonl`, `final/flutter-test-cases.json`.

## Browser blocker and remaining gaps

Chrome's isolated test tab loaded the local Flutter host, but stored console exceptions showed:

```text
TypeError: Failed to execute 'compile' on 'WebAssembly': HTTP status code is not ok
TypeError: Failed to fetch dynamically imported module: /canvaskit/chromium/canvaskit.js
```

CanvasKit JS/WASM files exist in the local SDK and the host HTML returned HTTP 200. The case never started. The owned test Chrome process was closed after diagnosing the bootstrap hang; runner then exited 1 with `Connection closed before test suite loaded`. No other browser session was terminated. The Windows SDK CanvasKit serving path needs separate tooling investigation or a supported environment; this task does not claim that web test passed and does not alter SDK source.

Remaining: PostgreSQL median SQL/migrations/query translation/transactions, HTTP middleware authorization, full MQTT reading persistence/reconnect and durable dispatch idempotency. The isolated dispatch helper tests publication marking and failure preservation; it does not prove background restart recovery or exactly-once delivery. Dio has no shared concurrent-refresh feature; concurrency deduplication is tested only for ApiService, where it already exists.

Product decision: backend supports overnight scheduling, but the Cupertino form currently rejects it. Behavior is preserved and tested; requirements must be chosen before a wider behavior change. Hardware discovery, 5GHz detection, location/crop persistence and physical pump auto-off are not claimed as tested.

`graphify update .` was attempted as required by AGENTS.md, but `graphify` is not installed/on PATH and no `graphify-out/graph.json` exists. No graph was generated or tool installed.

## Reproduce

From the repository root, use a fresh run ID in `YYYYMMDD-HHmmss` format (Asia/Saigon). Ensure the local Flutter SDK path matches this workspace and NuGet/Dart package resolution is available.

Create ignored `frontend/.env` with the single loopback key described above. Dependency preparation:

```powershell
dotnet restore backend/tests/IOTAgriBackend.Tests.csproj
.\.runtime\flutter\bin\flutter.bat pub get --directory frontend
```

The Flutter command may require Windows Developer Mode for platform plugin symlinks. Do not commit `.env` or generated SDK/cache/build files.

```powershell
$runId = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('yyyyMMdd-HHmmss')
.\tools\run-unit-checks.ps1 -RunId $runId -Phase final -Check backend
.\tools\run-unit-checks.ps1 -RunId $runId -Phase final -Check frontend
.\tools\run-unit-checks.ps1 -RunId $runId -Phase final -Check build
.\tools\run-unit-checks.ps1 -RunId $runId -Phase final -Check analyze
.\tools\run-unit-checks.ps1 -RunId $runId -Phase final -Check web
.\tools\sanitize-unit-artifacts.ps1 -RunId $runId
.\tools\summarize-unit-checks.ps1 -RunId $runId
```

The web command can stall at SDK bootstrap in the observed environment; treat it separately. Backend and Flutter VM tests do not require starting the application's database, broker or Docker stack. Logs include the exact expanded command, working directory, timestamps and captured exit code. Development logs record selected intermediate failures and dated check snapshots; baseline and final results are separate. The final `<check>.log` and `<check>.json` files are authoritative for the handoff state; earlier snapshots are not evidence for that state.

## Handoff and privacy

Log/TRX/coverage artifacts are sanitized for user/machine identifiers, workspace/cache paths and credential patterns. Raw collector attachment directories were moved into ignored `.run/unit-tests-raw/20261013-135436/`; no raw SDK/cache/build output is part of the suggested staging list. Published TRX attachments point to the normalized coverage file. Synthetic fixture identifiers/signing keys in test source are test-only and not production credentials.

See `../../changed-files.md` for explicit paths belonging to this task. `git diff --check`, status, ignore rules and a sensitive-pattern scan are reviewed before handoff. Suggested commit message: `test: add meaningful AEROGREEN unit tests and verification reports`.

No commit hash or pushed branch is supplied because the user explicitly reserved staging, commit and push for themselves.
