# Implementation Plan: Admin UI Backend

## Current State

`CupertinoAdminDashboardScreen` exposes eight tabs: overview, users, devices,
tickets, monitoring, logs, system configuration, and reports. Every tab reads
`MockAdminService`; `ApiService` has no admin methods. The backend already
protects six routes with `AdminOnly`:

- `GET /api/admin/users`
- `PUT /api/admin/users/{userId}/role`
- `GET /api/admin/devices`
- `GET /api/admin/devices/{id}/readings`
- `PUT /api/admin/devices/{id}/owner`
- `GET /api/admin/audit-logs`

Roles are seeded, but normal registration always creates `User`. No admin
bootstrap account exists. Tickets, system settings, notification delivery,
runtime metrics, report export, user lock/delete, device delete, and structured
logs do not exist in the backend.

## Decisions

- Keep one protected `/api/admin` group. Reuse JWT role claims and `AdminOnly`.
- Replace mocks with typed `ApiService` methods and DTOs. Do not add a second
  HTTP client or state library.
- Seed an administrator only from explicit environment secrets. Never add a
  public "make admin" endpoint or hard-code credentials.
- Preserve devices and their history. Admins can reassign or unassign owners;
  device deletion stays absent until archive/delete retention rules exist.
- Keep password reset disabled until an email provider is configured. Never
  return reset tokens to an administrator.
- Start logs with existing admin audit records. Do not invent a general log
  pipeline for this UI.
- Export CSV first. Keep PDF disabled until a document format and generator are
  approved.
- Global settings persist only values that affect existing behavior. Push,
  email, SMS, and maintenance mode remain disabled until each has a real
  delivery or enforcement path.

## Page Contract

| UI page | Real backend needed | Existing coverage |
| --- | --- | --- |
| Overview | counts, unresolved alerts, open tickets, service status | none |
| Users/detail | paginated search, lock state, role update, owned devices | list and role only |
| Devices/detail | server filters, latest readings, pump state/history, owner update | list, readings, owner only |
| Tickets/detail | tickets, messages, status, priority, admin reply | none |
| Monitoring | API, PostgreSQL, MQTT connection and ingestion status | `/health` only |
| Logs | paginated admin audit records with filters | audit list only |
| Configuration | persisted alert defaults with runtime effect | none |
| Reports | aggregate counts and CSV export | none |

## Tasks

### Task 1: Admin access and existing endpoint client

**Description:** Add environment-only administrator bootstrap. Add typed admin
DTOs and authenticated `ApiService` methods for the six existing admin routes.
Replace the matching device/role/audit mock reads.

**Acceptance criteria:**

- [x] Empty bootstrap secrets create no account; supplied secrets create or
  update one `Admin` account without logging its password.
- [x] A normal user receives `403`; an administrator can call every existing
  route through Flutter.
- [x] Admin UI displays backend errors instead of mock data.

**Verification:** focused bootstrap and authorization tests; Flutter API-client
tests; `dotnet test`; `flutter test`; Compose login as bootstrap admin.

**Dependencies:** None.

**Files likely touched:** `backend/Data/`, `backend/Program.cs`,
`backend/tests/`, `frontend/lib/services/api_service.dart`, admin DTO/model
files. **Scope:** Medium.

### Task 2: User administration that is safe to operate

**Description:** Extend user responses with lock status and search/filter
support. Add a user-detail response and lock/unlock endpoint using Identity
lockout. Wire user list/detail screens. Remove fake delete/reset controls until
retention and email-provider decisions exist.

**Acceptance criteria:**

- [x] Search and Active/Locked/Admin filters return paginated correct results.
- [x] Admin cannot lock self or the last administrator.
- [x] Role and lock changes create audit records; passwords/tokens never do.

**Verification:** endpoint authorization, last-admin, lockout, and paging
tests; Flutter list/detail tests; manual login refusal for locked user.

**Dependencies:** Task 1.

**Files likely touched:** `backend/Endpoints/AdminEndpoints.cs`, admin DTOs,
`backend/Services/AdminRoleRules.cs`, tests, user admin screens. **Scope:**
Medium.

### Task 3: Device oversight detail

**Description:** Add server-side search/status filters and one admin device
detail response containing latest reading, current pump state, recent pump
commands, and owner. Wire device list/detail and the existing owner update.
Replace fake device delete with unassign owner.

**Acceptance criteria:**

- [x] Filters, detail, readings, pump history, reassignment, and unassignment
  work only for admins.
- [x] A former owner loses access after unassignment or reassignment.
- [x] Every ownership action is audited; device/readings/commands remain.

**Verification:** authorization and ownership-isolation tests; Flutter device
screen test; Compose reassignment check.

**Dependencies:** Task 1.

**Files likely touched:** `backend/Endpoints/AdminEndpoints.cs`, admin DTOs,
`frontend/lib/services/api_service.dart`, device admin screens, tests. **Scope:**
Medium.

### Task 4: Support ticket persistence and admin API

**Description:** Add `SupportTicket` and `SupportTicketMessage` models,
migration, request/response DTOs, and admin-only list/detail/status/priority/
reply routes. Record actor and changes in audit logs.

**Acceptance criteria:**

- [x] Tickets paginate, search, and filter by Open/In progress/Closed.
- [x] Admin can change status/priority and reply; messages retain author and
  UTC time.
- [x] Cross-ticket access and invalid transitions return safe errors.

- [x] Authenticated users can create a ticket from the dashboard.

**Verification:** migration, endpoint, transition, and authorization tests;
Compose CRUD check.

**Dependencies:** Task 1.

**Files likely touched:** models, `ApplicationDbContext`, migration, admin
endpoints/DTOs/tests. **Scope:** Medium.

### Task 5: Wire ticket screens

**Description:** Replace ticket mock loading and in-memory mutations with Task
4 routes. Keep screen behavior, loading, empty, and error states.

**Acceptance criteria:**

- [x] List, detail, reply, status, and priority survive reload.
- [x] UI does not report success when backend rejects a change.

**Verification:** Flutter widget tests and Android manual flow.

**Dependencies:** Task 4.

**Files likely touched:** `ApiService`, ticket screens, widget tests. **Scope:**
Medium.

### Task 6: Overview, audit log, report summary, and CSV

**Description:** Add one admin summary endpoint for UI counts, unresolved
alerts, and open tickets. Extend audit-log filters. Add report summary and CSV
download generated from the same queries. Use CSV only; disable PDF button.

**Acceptance criteria:**

- [x] Overview and report counts agree with database queries.
- [x] Log filters return only authorized audit records.
- [x] CSV has correct UTF-8 headers, values, and content disposition.

**Verification:** aggregate/filter/export endpoint tests; Flutter overview/log/
report tests; download check.

**Dependencies:** Tasks 2-4.

**Files likely touched:** admin endpoints/DTOs/tests, `ApiService`, overview,
logs, reports screens. **Scope:** Medium.

### Task 7: Minimal real monitoring

**Description:** Add admin-only status endpoint with API liveness, PostgreSQL
connectivity, MQTT connection state, latest ingestion time, and device counts.
Do not expose fake CPU/RAM/message-rate values.

**Acceptance criteria:**

- [x] Failed database or MQTT state reports degraded, never stale mock values.
- [x] Monitoring screen refreshes and labels unavailable metrics clearly.

**Verification:** unit tests for status mapping; Compose stop/start dependency
check; Flutter error/degraded state test.

**Dependencies:** Task 1.

**Files likely touched:** `MqttIngestionService`, admin endpoint/DTO/tests,
monitoring screen. **Scope:** Medium.

### Task 8: Persisted global settings with real effects

**Description:** Add singleton system settings for defaults already supported by
alert evaluation. Apply defaults only when a device has no explicit override.
Persist settings and audit each update. Leave notification and maintenance
switches disabled and explained in UI.

**Acceptance criteria:**

- [x] Admin reload sees saved values.
- [x] Changed default affects only devices without an override.
- [x] No switch claims email/SMS/push delivery or maintenance enforcement.

**Verification:** migration and fallback-rule tests; admin authorization test;
Flutter configuration save/reload test.

**Dependencies:** Task 1.

**Files likely touched:** settings model/migration, alert rules/endpoints/tests,
configuration screen. **Scope:** Medium.

## Checkpoints

### After Tasks 1-3

- [ ] Admin can log in using explicit bootstrap secrets.
- [ ] Users and devices show live data; no mock user/device data remains.
- [ ] `dotnet test`, `flutter test`, and Android smoke flow pass.

### After Tasks 4-6

- [x] Tickets, overview, audit log, reports, and CSV survive reload.
- [ ] No passwords, tokens, device keys, or private readings leak.

### Complete

- [x] Monitoring reports real dependency state.
- [x] Settings change real supported behavior only.
- [ ] Remove `MockAdminService` when no screen imports it.
- [ ] Run full tests, Compose smoke check, `graphify update .`, and graph
  diagnosis.

## Open Product Decisions

- User deletion: prohibit, anonymize, or hard-delete after device/ticket
  reassignment?
- Password reset: which transactional email provider and sender domain?
- PDF: required server-generated document format, or CSV-only release?
- Notification delivery: push, email, SMS provider and consent policy?
- Maintenance mode: which API/device operations must be blocked?
