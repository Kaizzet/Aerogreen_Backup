# AEROGREEN unit test plan

Scope: ASP.NET Core and both Flutter entrypoints; no firmware/native/E2E or live PostgreSQL/MQTT. Existing branch and user changes must remain intact. Final status and measurements are in the run report.

| Module | Production behavior | Existing evidence | Additional checks | Type | Status |
|---|---|---|---|---|---|
| Backend JWT | Signing, claims, roles, expiry, refresh entropy | None | Fixed clock, signature validation, missing key, unique identifiers | Unit | Implemented |
| Backend profile/provisioning | Length/normalization; alphabet/hash | Basic rules | Exact boundaries, case-sensitive matching | Unit | Implemented |
| Backend alerts | Water bounds and pagination | Threshold triggers/default overrides | Finite/NaN/infinity and inclusive limits | Unit | Implemented |
| Backend pump | Duration and duplicate request payload | Basic request rules | Empty ID, lower/upper bounds, cross-device conflict | Unit | Implemented |
| Backend MQTT | QoS1 publish, status acknowledgment, errors | JSON contract | Inject client, payload, caller-managed retry ID, cancellation/timeout, status application | Unit | Implemented; persistence remains integration gap |
| Backend schedule | Overlap, intervals, timezone/DST | DST and overnight cases | Adjacent windows, invalid pair, empty due window | Unit | Implemented |
| Backend admin/ticket | Last admin/self protection; transitions | Rule + route metadata | Unlock/promotion and invalid transitions | Unit | Implemented; HTTP authorization remains gap |
| Flutter add-device | Discovery simulation, Wi-Fi/name validation, API save | 35 placeholders + browser widget | Actual widgets, fake API, pending/success/error/API timeout | Widget | Implemented: 9 widget cases; browser bootstrap blocked |
| Flutter pump | Offline, pending, duration choices, low-water guard | 22 placeholders + detail widgets | Production card/detail interactions, fake API | Widget | Implemented: 11 widget cases |
| Flutter transport | DTO mapping, HTTP errors, token refresh | Ticket fake, config only | HTTP/Dio fake adapters, retry bounds, shared refresh, storage failure | Unit | Implemented |
| Flutter auth/default router | Auth state, login/logout/storage errors, redirect | Cupertino auth widgets only | Fake repository/provider and default app/router/UI | Unit/widget | Implemented: 2 unit + 1 widget cases |
| Flutter schedule | Production validation | Two tests duplicate validation inside test | Extract existing form validation and call it from both form and tests | Unit | Implemented; overnight discrepancy preserved and reported |
| PostgreSQL/authorization/dispatch | SQL median, migrations, transactions, durable dispatch idempotency | No service-backed suite | Separate HTTP/PostgreSQL/MQTT integration suite | Integration | Deferred; not verified by unit tests |

57 original placeholder assertions are not evidence. Unsupported QR/BLE hardware, 5GHz discovery, location/crop persistence and automatic physical pump shutdown must not be invented to satisfy their old descriptions.

Logs use `docs/testing/runs/<run-id>/{baseline,final}`. Use `tools/run-unit-checks.ps1`; snapshot native exit codes immediately. No aggregate C#/Dart coverage threshold. Local `frontend/.env` contains only a loopback test URL and stays ignored. No Git staging/branch/commit/push operations.
