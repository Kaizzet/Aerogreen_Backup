# IOTAgri

IoT hydroponics/agriculture monitoring system with an ASP.NET Core backend and Flutter frontend.

## Tech Stack

- **ASP.NET Core 10** (Minimal API)
- **PostgreSQL** via Entity Framework Core (`Npgsql.EntityFrameworkCore.PostgreSQL`)
- **ASP.NET Core Identity** + JWT bearer authentication (access + refresh tokens)
- **MQTT** (MQTTnet) for real-time sensor ingestion from ESP32 devices, via a local Mosquitto broker in dev
- **Swagger / OpenAPI** for API exploration in Development
- **GitHub Actions CI** for tests, Release builds, and Docker image builds
- **Flutter Frontend** - Mobile app for device management and monitoring

## Features Implemented So Far

### Auth
- `POST /api/auth/register`, `/login`, `/refresh`, `/logout`
- Email-based accounts, `User`/`Admin` roles, DB-backed refresh token rotation

### Device Management
- `POST /GET /PUT /DELETE /api/devices` (+ `/api/devices/{id}`)
- Each device gets a unique `DeviceKey` used to authenticate its MQTT publishes
- Devices are scoped per owning user

### Sensor Ingestion (MQTT)
- ESP32 devices publish JSON readings to `devices/{deviceKey}/readings` on the MQTT broker
- A background service (`MqttIngestionService`) subscribes, validates the device key, and persists readings
- `GET /api/devices/{deviceId}/readings` — reading history for a device

### Pump Control, Scheduling, and Alerts
- Authenticated owners can issue pump commands, view command history, and manage pump schedules.
- Sensor readings evaluate configured temperature and water-level thresholds, with active and resolved alert history.

### Dashboard / Aggregation
- `GET /api/dashboard/overview` — all of a user's devices with latest reading + online status
- `GET /api/devices/{deviceId}/readings/aggregated?interval=hour|day|...` — time-bucketed min/avg/max per metric, computed in PostgreSQL

### Administration
- Admins can manage user roles, view all devices/readings, reassign device ownership, and review audit logs.

## Local Development

**Requirements:** Docker Desktop. The Compose stack includes the API, PostgreSQL, and Mosquitto.

```powershell
# Copy the deployment settings, then set MQTT_PUBLIC_HOST to this PC's LAN IPv4.
Copy-Item .env.example .env
notepad .env

# Start the complete local stack.
docker compose up -d --build
Invoke-WebRequest http://localhost:8080/health
```

The API seeds the configured administrator on startup. Set a unique `ADMIN_EMAIL`,
`ADMIN_PASSWORD`, and `ADMIN_FULL_NAME` in `.env` before starting the stack; replace
the sample password, especially outside local development. The account is created
only if that email does not already exist, and the Admin role is ensured on each startup.

Swagger UI is available at `http://localhost:8080/swagger`.

### Connecting with pgAdmin

The PostgreSQL service is published only to this computer at `127.0.0.1`.
The Compose stack also includes a browser-based pgAdmin at `http://127.0.0.1:5050`.
Sign in with `PGADMIN_DEFAULT_EMAIL` and `PGADMIN_DEFAULT_PASSWORD` from `.env`, then
register a server using these connection fields:

- **Host name/address:** `postgres` (the Docker service name)
- **Port:** `5432`
- **Maintenance database:** value of `POSTGRES_DB` in `.env`
- **Username:** value of `POSTGRES_USER` in `.env`
- **Password:** value of `POSTGRES_PASSWORD` in `.env`

The standalone Windows pgAdmin app can use `127.0.0.1` and `POSTGRES_PORT` instead,
but the bundled pgAdmin avoids the Windows desktop runtime issue.

## Continuous Integration

GitHub Actions runs on pull requests and pushes to `main`. It restores dependencies, runs the test project, builds the API in Release mode, and builds the Docker image. It does not deploy to a VPS.

### Connecting an ESP32

1. Register and sign in through Swagger, then create a device with `POST /api/devices`.
2. Create its 15-minute, one-use setup code with authenticated `POST /api/devices/{deviceId}/provisioning-code`.
3. Upload [`firmware/ESP32DeviceSetup/ESP32DeviceSetup.ino`](firmware/ESP32DeviceSetup/ESP32DeviceSetup.ino), join Wi-Fi network `IOTAgri-Setup`, and open the shown setup page.
4. Install Arduino libraries `PubSubClient`, `DHT sensor library`, and `BH1750`, then wire DHT11 DATA to GPIO4, HC-SR04 TRIG to GPIO5 / ECHO to GPIO18, and BH1750 SDA/SCL to GPIO21/GPIO22. Put a level shifter or voltage divider between the 5 V HC-SR04 ECHO pin and GPIO18.
5. Set `EMPTY_DISTANCE_CM` and `FULL_DISTANCE_CM` near the top of the sketch to measured empty/full tank distances. Enter Wi-Fi details, `http://<PC-LAN-IP>:8080`, and the setup code. The ESP32 saves its settings and publishes temperature, humidity, water-level percentage, and lux every 10 seconds.

The local Mosquitto broker is anonymous and plaintext for trusted LAN development only. Do not expose port 1883 to the internet. A future production broker must use per-device credentials and TLS.

## Planned / Not Yet Implemented

- Production Compose hardening: reverse-proxy HTTPS, private API/PostgreSQL ports, restart policies, and off-server database backups
- Production MQTT: TLS, per-device credentials, and topic ACLs (the current broker is intentionally anonymous and plaintext for local development)
- ESP32 HTTPS and MQTT TLS support
- VPS deployment and continuous deployment after the production stack is verified

## Frontend Application

### Flutter Mobile App

A Flutter frontend application is included in the `frontend/` directory with the following features:

- **Authentication**: Login and registration with JWT token management
- **Dashboard**: Overview of all devices with sensor readings and status
- **Device Management**: Add, edit, delete devices, view device details
- **Sensor Monitoring**: Real-time temperature, humidity, pH, TDS, and water level readings
- **Pump Control**: Manual pump control and scheduling
- **Alerts**: Threshold-based notifications for temperature and water level

### Frontend Tech Stack

- **Framework**: Flutter 3.10+
- **Language**: Dart
- **State Management**: Provider
- **HTTP Client**: http package
- **Secure Storage**: flutter_secure_storage
- **Date Formatting**: intl
- **Charts**: fl_chart

### Running the Frontend

```bash
cd frontend
flutter pub get
flutter run
```

### Frontend Platforms

- Android
- iOS
- Web
- Windows
- macOS
- Linux

All UI is in Vietnamese with Arial font as requested.
