# AEROGREEN test case inventory

Run evidence: `runs/20261013-135436/report.md`. Individual executed Dart cases and results: `runs/20261013-135436/final/flutter-test-cases.json`. Individual C# results: `runs/20261013-135436/final/backend.trx`.

## Added backend cases (40)

| Source | Cases | Production behavior / assertions |
|---|---:|---|
| `backend/tests/TokenServiceTests.cs` | 4 | Default/configured expiry with fixed TimeProvider; JWT signature/issuer/audience/claims/roles; unique JTI; missing key; refresh byte length/uniqueness |
| `backend/tests/RuleBoundaryTests.cs` | 24 | Pump duration/empty ID; alert finite water bounds/pagination; normalized maximum profile length; provisioning alphabet/hash/case; ticket transitions; last-admin/self restrictions; schedule mask/window/interval/adjacency/disabled occurrences |
| `backend/tests/PumpCommandRulesTests.cs` | 6 | Duplicate payload equality and cross-device conflict; repeated acknowledgment, success/rejection/fallback reason with fixed time |
| `backend/tests/MqttPublisherTests.cs` | 3 | Disconnected gate; QoS1/topic/payload and same command ID across caller retry; timeout/cancellation propagation through injected client |
| `backend/tests/AccessAndDispatchTests.cs` | 3 | Actual owner predicate from pump endpoint; failed/cancelled publication leaves occurrence unmarked; successful retry reuses ID and marks fixed timestamp |

The publisher test calls publication twice; it does not prove a background retry cycle or exactly-once broker delivery. Dispatch attempt tests do not prove PostgreSQL unique constraints, persistent recovery or transactional idempotency. The owner predicate test does not prove HTTP middleware authorization.

## Flutter changes

| Source | Cases | Type | Production behavior / assertions |
|---|---:|---|---|
| `frontend/test/add_device_test.dart` | 9 | Widget | Preparation/back, QR disabled while scanning, simulated BLE selection, Wi-Fi/name validation, pending save/success, claimed/API error/API timeout and retry-enabled state |
| `frontend/test/pump_control_test.dart` | 11 | Widget | Online/pending gates, countdown display/stop callback, four actual duration choices (30/60/300/600), production API payload interaction, low-water block and API timeout state |
| `frontend/test/api_session_test.dart` | 8 | Unit | Provisioning route/mapping/failure; rotation/retry; pending refresh deduplication for concurrent requests; rejected refresh/storage clearing; bounded retry; transient error retention; login storage failure |
| `frontend/test/dio_http_test.dart` | 5 | Unit | Pump payload/result mapping; HTTP 503; refresh success; refresh rejection and repeated 401 terminate rather than recursive refresh |
| `frontend/test/default_auth_test.dart` | 3 | 2 unit, 1 widget | Pending/login state; storage restore/logout error handling; actual default app/router redirect and form validation before repository call |
| `frontend/test/phase13_widget_variants_test.dart` | 2 replaced | Unit | Calls shared production form validation rather than a function copied into test; inclusive bounds and current time-window behavior |

Existing meaningful tests are retained. Original 35 add-device and 22 pump placeholder declarations were consolidated into 20 production widget cases; this is not a one-for-one rename. Remaining descriptions for hardware QR/BLE discovery, arbitrary 5GHz networks, location/crop persistence, physical pump shutdown, haptics, reminders and full firmware flow are not claimed as verified.

All new HTTP interactions use fake transport/repository/storage. Widget timers advance through the test fake clock, not wall-clock sleeps. Default auth fonts use local SDK font bytes through a test asset handler; no font download is required. Existing unrelated tests may still have their own time dependencies.

## Integration and product decisions still needed

- PostgreSQL SQL median, migrations, query translation and transactions require a service-backed suite.
- JWT lifetime middleware, 401/403 HTTP authorization and all ownership paths need HTTP integration tests; current rule/metadata tests are narrower.
- MQTT sensor persistence, background reconnect and durable dispatch recovery/idempotency are not verified against a real broker/database.
- Dio refresh requests are bounded, but no shared concurrent-refresh orchestration is implemented or claimed. ApiService already has a shared pending refresh and is tested for it.
- Cupertino form rejects overnight windows while backend supports them. Its existing validation is preserved; select the intended UI requirement before changing it.
- Browser-only test is attempted separately and blocked by CanvasKit bootstrap; no browser case counted as pass.
