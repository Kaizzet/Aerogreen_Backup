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

Run the following commands in **PowerShell** from the project root (the directory containing `compose.yaml`).

**Requirements:** Docker Desktop running with Linux containers and Docker Compose. The Compose stack includes the API, PostgreSQL 17, and Mosquitto. You do not need a local .NET SDK to run the backend through Docker.

### 1. Configure the environment

```powershell
# Create the configuration only if it does not already exist.
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
notepad .env

# Find this PC's LAN IPv4 address.
ipconfig
```

Update these values in `.env` before starting:

| Variable | Description |
| --- | --- |
| `POSTGRES_DB` | Database name; the example uses `iotagri` |
| `POSTGRES_USER` | PostgreSQL username |
| `POSTGRES_PASSWORD` | Set a unique database password |
| `POSTGRES_PORT` | Local-only PostgreSQL host port; default `5432` |
| `PGADMIN_PORT` | Local-only pgAdmin host port; default `5050` |
| `PGADMIN_DEFAULT_EMAIL` / `PGADMIN_DEFAULT_PASSWORD` | pgAdmin sign-in credentials |
| `JWT_KEY` | Set a unique signing key with at least 32 characters |
| `ADMIN_BOOTSTRAP_EMAIL` / `ADMIN_BOOTSTRAP_PASSWORD` | Credentials for the initial administrator; replace sample values |
| `ADMIN_BOOTSTRAP_FULL_NAME` | Display name for the initial administrator |
| `API_PORT` | Host API port; the example uses `8080` |
| `MQTT_PORT` | Host MQTT port; the example uses `1883` |
| `MQTT_PUBLIC_HOST` | This PC's LAN IPv4, reachable by the ESP32 |

For example, if your PC's IPv4 is `192.168.1.100`, set `MQTT_PUBLIC_HOST=192.168.1.100`. Replace example IP addresses in this README with your PC's actual address.

The root `.env` configures Docker Compose. Flutter's API URL is configured separately with `--dart-define=API_BASE_URL=...`.

The API seeds roles and the configured administrator on startup. The administrator
account is created only if its email does not already exist, and its Admin role is
ensured on each startup. Replace all sample credentials, especially outside local
development.

### 2. Start the backend stack

```powershell
docker compose up -d --build
docker compose ps
docker compose logs -f api
```

The first build can take several minutes to download images and restore dependencies. Press `Ctrl+C` to stop following logs; the containers keep running.

The API applies Entity Framework Core migrations and seeds roles and the configured
administrator during startup. No manual database table creation is needed.

### 3. Verify the API

Once the API has started:

```powershell
Invoke-RestMethod http://localhost:8080/health
```

Expected response: `status` is `ready`.

| Service | Address with the example configuration |
| --- | --- |
| API | `http://localhost:8080` |
| Swagger UI | `http://localhost:8080/swagger` |
| Health check | `http://localhost:8080/health` |
| MQTT from your LAN | `<PC-LAN-IP>:1883` |
| PostgreSQL from this PC | `127.0.0.1:5432` |
| pgAdmin | `http://127.0.0.1:5050` |

PostgreSQL and pgAdmin ports are bound to this PC only. If you change `API_PORT`,
`MQTT_PORT`, `POSTGRES_PORT`, or `PGADMIN_PORT`, use the updated port in client
connections. PostgreSQL remains available to containers at `postgres:5432`.

### 4. Register and create a device

Register and sign in through the Flutter app or Swagger (`POST /api/auth/register`, `POST /api/auth/login`). In Swagger, authorize with the returned access token before calling authenticated endpoints. Create a device with `POST /api/devices`, then connect an ESP32 or use the optional simulator below.

### Optional: test without an ESP32

The `pump-simulator` service acknowledges pump commands and can publish sample sensor
readings every 10 seconds. After creating a device, retrieve its `deviceKey` from the
device API and add it to `.env`:

```dotenv
PUMP_SIMULATOR_DEVICE_KEY=your-device-key
```

Start the simulator from the project root:

```powershell
docker compose --profile pump-simulator up -d pump-simulator
docker compose logs -f pump-simulator
```

Without `PUMP_SIMULATOR_DEVICE_KEY`, the simulator only acknowledges pump commands.
It does not publish sample readings or control physical hardware.

Scheduled pump dispatch is disabled by default. To enable it, add
`PUMP_SCHEDULING_ENABLED=true` to `.env` and restart the API with
`docker compose up -d api`.

### Stop, restart, and inspect logs

Run these commands from the project root:

```powershell
# Stop all services, including the optional simulator; retain database volumes.
docker compose --profile pump-simulator down

# Start the main stack again.
docker compose up -d

# Rebuild the API after changing backend code.
docker compose up -d --build api

# Inspect recent logs.
docker compose logs --tail 100 api postgres mosquitto
```

Avoid `docker compose down -v` if you want to retain database data.

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

- **Framework**: Flutter with Dart SDK compatible with `^3.10.7` (see `frontend/pubspec.yaml`)
- **Language**: Dart
- **State Management**: Provider
- **HTTP Client**: http package
- **Secure Storage**: flutter_secure_storage
- **Date Formatting**: intl
- **Charts**: fl_chart

### Running the Frontend

Install Flutter and check the available development tools:

```powershell
flutter --version
flutter doctor
```

Open a second terminal at the project root, then install frontend dependencies:

```powershell
cd frontend
flutter pub get
flutter devices
```

#### Web (Chrome)

With the Docker backend running:

```powershell
flutter run -d chrome --web-hostname localhost --web-port 8081 --dart-define=API_BASE_URL=http://localhost:8080
```

Open `http://localhost:8081`. This origin is already allowed by the API's Compose CORS configuration.

#### Android Emulator

Start an Android Emulator and use its ID from `flutter devices` (replace `emulator-5554` if different):

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` reaches the development PC from Android Emulator. `localhost` inside the emulator refers to the emulator itself.

#### Physical Android device

Enable USB debugging, connect the phone, and replace `YOUR_DEVICE_ID` with its ID from `flutter devices`:

```powershell
flutter run -d YOUR_DEVICE_ID --dart-define=API_BASE_URL=http://192.168.1.100:8080
```

Replace the IP with your PC's LAN IPv4. The phone and PC must be on the same LAN. Allow the API port through Windows Firewall on your private network if needed. Test connectivity from the phone's browser at `http://<PC-LAN-IP>:8080/health`.

**API URL:** The source default is `http://localhost:5261`, while Docker exposes port `8080` with the example configuration. Pass `API_BASE_URL` explicitly when using Docker. Stop and rerun Flutter after changing `--dart-define`; creating a Flutter `.env` file does not set this value.

Press `Ctrl+C` in the Flutter terminal to stop the app.

### Frontend Platforms

- Android
- iOS
- Web
- Windows
- macOS
- Linux

The application UI is in Vietnamese and uses Arial.

## Troubleshooting

| Issue | Check / solution |
| --- | --- |
| Docker daemon unavailable | Open Docker Desktop, wait for the engine, and use Linux containers |
| API or MQTT port already in use | Change `API_PORT` or `MQTT_PORT` in `.env`, rerun Compose, and update client URLs |
| API startup or health check fails | Inspect `docker compose ps` and `docker compose logs --tail 100 api postgres` |
| PostgreSQL password fails after editing `.env` | An existing database volume retains its original password; restore the old setting or update the database account |
| Web CORS error | Use `http://localhost:8081`; for another origin, update `Cors__AllowedOrigins__...` on the API service and rerun Compose |
| Frontend cannot reach the API | Check the platform-specific URL, port, and `/health`; rerun Flutter after changing `API_BASE_URL` |
| Phone or ESP32 cannot connect | Check LAN access, the PC's current IPv4, firewall, and `MQTT_PUBLIC_HOST` |
| ESP32 does not publish readings | Inspect Serial Monitor, API/Mosquitto logs, provisioning, and sensor wiring |
| Flutter SDK constraint error | Ensure the bundled Dart SDK satisfies `^3.10.7`, then rerun `flutter pub get` |

## Development Checks

For backend tests and builds, install .NET SDK 10 and run from the project root:

```powershell
dotnet test backend/tests/IOTAgriBackend.Tests.csproj --configuration Release
dotnet build backend/IOTAgriBackend.csproj --configuration Release
```

For frontend checks:

```powershell
cd frontend
flutter analyze
flutter test
```

## Project Structure

```text
IOTAgri/
├── backend/                 # ASP.NET Core API, migrations, and tests
├── frontend/                # Flutter application
├── firmware/                # ESP32 sketch
├── mosquitto/               # MQTT broker configuration
├── tools/                   # Simulator scripts
├── .env.example             # Example Compose environment
├── compose.yaml             # API, PostgreSQL, MQTT, optional simulator
└── Dockerfile               # Backend container build
```

Do not commit `.env` or real credentials. The current Compose stack runs the API in Development and is intended for local development.
