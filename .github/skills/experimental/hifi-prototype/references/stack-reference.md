# Stack Quick-Reference

Per-stack setup commands, storage options, and telemetry implementation details.

## HTML/CSS/JS (default, no backend)

```bash
# Just open it
open index.html
# Or use a simple server for telemetry flush
npx serve .
```

Storage: `localStorage` + JSON files in `data/` (manual export).
Telemetry: events buffer in `localStorage`, export to JSON on demand.

## Python (Flask)

```bash
pip install flask
python app.py
# → http://localhost:5000
```

Storage: SQLite via `sqlite3` stdlib or JSON files.
Telemetry: OpenTelemetry SDK with `opentelemetry-exporter-otlp` or file export.

## Node.js (Express)

```bash
npm install express better-sqlite3
node server.js
# → http://localhost:3000
```

Storage: SQLite via `better-sqlite3` or JSON files.
Telemetry: `@opentelemetry/sdk-node` with file exporter.

## .NET (Minimal API)

```bash
dotnet new web -n {name}
dotnet run
# → http://localhost:5000
```

Storage: SQLite via `Microsoft.Data.Sqlite` or JSON files.
Telemetry: `OpenTelemetry.Extensions.Hosting` with file exporter.

## Simulation Approaches

| Need                   | Approach                                                                          |
|------------------------|-----------------------------------------------------------------------------------|
| API responses          | JSON fixture files in `sim/fixtures/` returned by a mock route                    |
| Sensor/IoT data        | CSV or JSON time-series files replayed at configurable speed                      |
| AI/ML predictions      | LLM call with a system prompt describing expected behavior, or a decision tree    |
| User-generated content | Seeded SQLite database or JSON files with realistic sample data                   |
| External service calls | Stub functions that log the call and return canned responses                      |

## Telemetry Implementation

**Frontend**: a small `telemetry.js` module (~50 lines) that captures events
and writes them to `localStorage`, then flushes to a local JSON file via
a backend endpoint or on page unload.

**Backend** (if present): OpenTelemetry SDK with a file exporter writing to
`telemetry/traces.json` and `telemetry/events.json`.

No external services unless the user explicitly requests one of:

* **Application Insights**: instrument with the JS SDK, connection string in `.env`.
* **OpenTelemetry Collector**: export spans and metrics to a local OTLP endpoint
  or a remote collector. Provide a `docker-compose.yml` for a local Jaeger
  or Zipkin instance.
