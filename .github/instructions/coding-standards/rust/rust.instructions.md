---
applyTo: '**/*.rs'
description: 'Required instructions for Rust research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core'
---

# Rust Instructions

Conventions for Rust development targeting the 2021 edition.

## Project Structure

Crates follow a standard layout:

```text
Cargo.toml
Cargo.lock
src/
  main.rs           # Binary crate entry point
  lib.rs            # Library crate root
  module_name.rs    # Top-level module
  module_name/
    mod.rs           # Module with submodules
    submodule.rs
tests/
  integration_test.rs
```

* `Cargo.toml` and `Cargo.lock` at crate root.
* Commit `Cargo.lock` for binary crates to ensure reproducible builds. Exclude it from version control for library crates.
* `src/` contains all source files.
* Binary crates use `main.rs`; library crates use `lib.rs`.
* Test projects use a sibling `tests/` directory for integration tests.
* Keep crate roots thin with module declarations and re-exports.

Project folder organization scales with complexity. Keep all files at root-level modules when fewer than 10 source files exist. When folders become necessary, organize by domain responsibility: `config`, `error`, `handlers`, `models`, `services`.

## Cargo.toml Conventions

### Standard Fields

<!-- <example-cargo-toml> -->
```toml
[package]
name = "service-name"
version = "0.1.0"
edition = "2021"
license = "MIT"

[dependencies]
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
thiserror = "2"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
```
<!-- </example-cargo-toml> -->

Sections below reference additional crates (`reqwest`, `tokio-retry`, `async-trait`). Add them to `[dependencies]` when using those patterns.

### Dependency Management

* Use caret ranges for stable public crates: `version = "1"`.
* Pin exact versions for private or unstable SDKs: `version = "=1.1.3"`.
* Disable default features when targeting WASM or minimal builds: `default-features = false`.
* Specify only needed feature flags to reduce compile time and binary size.

### Release Profile

<!-- <example-release-profile> -->
```toml
[profile.release]
strip = true
lto = true
codegen-units = 1
panic = "abort"
```
<!-- </example-release-profile> -->

Use `strip = true` to remove debug symbols. Enable `lto` and `codegen-units = 1` for optimized builds. Set `panic = "abort"` for smaller binaries when stack unwinding is unnecessary.

## Coding Conventions

### Naming

| Element         | Convention           | Example                       |
|-----------------|----------------------|-------------------------------|
| Types & Structs | PascalCase           | `UserService`, `DeviceConfig` |
| Traits          | PascalCase           | `Repository`, `Serializer`    |
| Enum Variants   | PascalCase           | `Status::Active`              |
| Functions       | snake_case           | `process_request`             |
| Variables       | snake_case           | `device_url`, `retry_count`   |
| Constants       | SCREAMING_SNAKE_CASE | `DEFAULT_TIMEOUT`             |
| Modules         | snake_case           | `error_handler`               |
| Crate Names     | kebab-case           | `my-service`                  |
| Feature Flags   | kebab-case           | `onnx-runtime`                |

### Type Naming Suffixes

Apply these suffixes consistently for domain types:

* Error types: `*Error` suffix (`ServiceError`, `ParseError`)
* Config types: `*Config` suffix (`AppConfig`, `DatabaseConfig`)
* Builder types: `*Builder` suffix (`RequestBuilder`, `SessionBuilder`)
* Result type aliases: `pub type Result<T> = std::result::Result<T, ServiceError>;`

### Module Structure

Member ordering within a module:

1. `use` declarations (standard library, external crates, internal modules)
2. Constants and statics
3. Type definitions (structs, enums, type aliases)
4. Trait definitions
5. Trait implementations
6. Inherent implementations
7. Free functions
8. Test module

Within categories, order: `pub` items before `pub(crate)` before private.

### Variable Declarations

Prefer type inference with `let` when the type is obvious from the right side. Use explicit type annotations when inference is ambiguous or the type aids readability:

```rust
let service = UserService::new(repo, logger);
let lookup: HashMap<String, Vec<Item>> = HashMap::new();
```

Prefer early returns over deep nesting. Use `if let` and `let ... else` for option/result unwrapping at control flow boundaries:

```rust
let Some(user) = repository.find(id).await? else {
    return Err(ServiceError::not_found("User not found"));
};
```

## Error Handling

### Custom Error Types

Use `thiserror` for library-style error enums. Define a module-scoped `Result` type alias to reduce boilerplate.

<!-- <example-error-handling> -->
```rust
use thiserror::Error;

pub type Result<T> = std::result::Result<T, ServiceError>;

#[derive(Error, Debug)]
pub enum ServiceError {
    #[error("Not found: {message}")]
    NotFound { message: String },

    #[error("Invalid input: {message}")]
    InvalidInput { message: String },

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),
}

impl ServiceError {
    pub fn not_found<S: Into<String>>(message: S) -> Self {
        Self::NotFound { message: message.into() }
    }

    pub fn invalid_input<S: Into<String>>(message: S) -> Self {
        Self::InvalidInput { message: message.into() }
    }
}
```
<!-- </example-error-handling> -->

### Error Handling Rules

* Use `thiserror` for error types in libraries and modules with structured error variants.
* Use `anyhow` only in application-level `main` functions or CLI tools where error granularity is unnecessary.
* Prefer `?` operator for error propagation over explicit `match` or `unwrap`.
* Never use `unwrap()` or `expect()` in production paths. Reserve them for cases with compile-time or initialization guarantees.
* Initialization paths include startup config loading in `main`, `OnceLock`/`LazyLock` initializers, and one-time setup that runs before the service accepts work. Use `expect()` with a descriptive message in these contexts.
* Provide context-aware error messages that include relevant state.
* Implement `#[from]` for delegating errors from external crates.
* Add helper constructors on error types for ergonomic creation.

## Async Patterns

### Tokio Runtime

Use Tokio as the async runtime. Select the flavor based on workload characteristics:

<!-- <example-tokio-runtime> -->
```rust
// Multi-threaded for high-concurrency services
#[tokio::main]
async fn main() -> Result<()> {
    // ...
}

// Single-threaded for lightweight or resource-constrained services
#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<()> {
    // ...
}
```
<!-- </example-tokio-runtime> -->

### Concurrent Task Management

* Use `tokio::select!` for racing independent tasks that should run concurrently until one completes.
* Use `tokio::try_join!` for collecting results from concurrent tasks that must all succeed.
* Use `tokio::spawn` for background tasks that run independently.
* Handle task cancellation and shutdown gracefully via `CancellationToken` or `tokio::select!`.
* Never block the async runtime with synchronous operations; use `tokio::task::spawn_blocking` instead.

<!-- <example-concurrency> -->
```rust
tokio::select! {
    result = background_task() => result?,
    result = server.run() => result?,
}
```
<!-- </example-concurrency> -->

### Async Trait Implementations

Use `async-trait` for trait definitions requiring async methods. The `async-trait` crate is required for the 2021 edition. Native async trait support is available in the 2024 edition and later.

```rust
use async_trait::async_trait;

#[async_trait]
pub trait Repository: Send + Sync {
    async fn find_by_id(&self, id: &str) -> Result<Option<Item>>;
    async fn save(&self, item: &Item) -> Result<()>;
}
```

## Observability

### Structured Logging

Use the `tracing` crate for all logging. Never use `println!` or `eprintln!` in production code.

<!-- <example-tracing> -->
```rust
use tracing::{info, warn, error, debug};
use tracing_subscriber::filter::EnvFilter;

tracing_subscriber::fmt()
    .with_env_filter(EnvFilter::from_default_env())
    .init();

info!(
    endpoint = %endpoint,
    interval_secs = %interval,
    "Starting service with configuration"
);

error!(
    error_code = "PUBLISH_FAILED",
    topic = %topic,
    "Failed to publish message: {:?}", err
);
```
<!-- </example-tracing> -->

### OpenTelemetry Integration

When distributed tracing is required, integrate OpenTelemetry via `tracing-opentelemetry`. Add `tracing-opentelemetry`, `opentelemetry`, `opentelemetry-sdk` (with the `rt-tokio` feature), and `opentelemetry-otlp` to `[dependencies]`.

* Check for `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable before enabling the exporter.
* Fall back to console-only logging when the variable is absent.
* Use `TraceContextPropagator` for W3C trace context propagation.

```rust
use std::env;

use tracing_subscriber::layer::SubscriberExt;

fn init_tracing() {
    let subscriber = tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env());

    if env::var("OTEL_EXPORTER_OTLP_ENDPOINT").is_ok() {
        let tracer = opentelemetry_otlp::new_pipeline()
            .tracing()
            .install_batch(opentelemetry_sdk::runtime::Tokio)
            .expect("OpenTelemetry pipeline must initialize at startup");

        let telemetry = tracing_opentelemetry::layer().with_tracer(tracer);
        tracing::subscriber::set_global_default(
            subscriber.finish().with(telemetry),
        ).expect("Global subscriber must be set once at startup");
    } else {
        subscriber.init();
    }
}
```

## Serialization

### Serde Patterns

* Derive `Serialize` and `Deserialize` using `serde` for all data transfer types.
* Use `#[serde(rename_all = "camelCase")]` when interfacing with JSON APIs that use camelCase.
* Implement `Default` for configuration types to provide sensible fallback values.
* Use `#[serde(default = "...")]` for fields with non-trivial defaults.

<!-- <example-serde> -->
```rust
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct AppConfig {
    pub endpoint: String,
    pub polling_interval_secs: u64,
    #[serde(default = "default_timeout")]
    pub timeout_ms: u64,
}

fn default_timeout() -> u64 { 5000 }

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            endpoint: String::new(),
            polling_interval_secs: 10,
            timeout_ms: default_timeout(),
        }
    }
}
```
<!-- </example-serde> -->

## Configuration Management

### Environment Variables

Define environment variable names as constants. Use `env::var` with clear error messages or sensible defaults.

<!-- <example-env-vars> -->
```rust
const ENDPOINT_VAR: &str = "SERVICE_ENDPOINT";
const INTERVAL_VAR: &str = "POLLING_INTERVAL";

let endpoint = env::var(ENDPOINT_VAR)
    .expect("SERVICE_ENDPOINT must be set");

let interval = env::var(INTERVAL_VAR)
    .unwrap_or_else(|_| "10".to_string())
    .parse::<u64>()
    .expect("POLLING_INTERVAL must be a valid u64");
```
<!-- </example-env-vars> -->

### File-Based Configuration

Support YAML and JSON configuration with validation:

```rust
impl AppConfig {
    pub fn from_file<P: AsRef<Path>>(path: P) -> Result<Self> {
        let content = std::fs::read_to_string(&path)?;
        let config: Self = serde_json::from_str(&content)?;
        config.validate()?;
        Ok(config)
    }

    pub fn validate(&self) -> Result<()> {
        if self.endpoint.is_empty() {
            return Err(ServiceError::invalid_input("Endpoint must not be empty"));
        }
        Ok(())
    }
}
```

### Static Initialization

Use `OnceLock` for thread-safe, one-time initialization of global state:

```rust
use std::sync::OnceLock;

static CONFIG: OnceLock<AppConfig> = OnceLock::new();
```

## Resilience Patterns

### Retry Logic

Use `tokio_retry` with exponential backoff for transient failures:

<!-- <example-retry> -->
```rust
use tokio_retry::{strategy::ExponentialBackoff, Retry};
use std::time::Duration;

let retry_strategy = ExponentialBackoff::from_millis(2000)
    .max_delay(Duration::from_secs(10))
    .take(5);

let result = Retry::spawn(retry_strategy, || async {
    client.send(&payload).await
}).await;
```
<!-- </example-retry> -->

## Visibility

* Default to private. Expose only what is needed at module boundaries.
* Use `pub(crate)` for types shared across modules within the same crate.
* Mark public API types with `pub` only when they form the crate's external contract.

### Feature Flags

Use Cargo feature flags for optional functionality:

```rust
pub enum Backend {
    #[cfg(feature = "backend-a")]
    BackendA(BackendAImpl),
    #[cfg(feature = "backend-b")]
    BackendB(BackendBImpl),
}
```

Declare features and gate optional dependencies in `Cargo.toml`:

```toml
[features]
default = []
backend-a = ["dep:backend-a-crate"]
backend-b = ["dep:backend-b-crate"]
```

Gate heavy dependencies behind features so downstream consumers control binary size.

## Code Documentation

Public and protected items require documentation comments.

Guidelines:

* Use `///` for item-level documentation on public types, functions, and modules.
* Use `//!` for module-level documentation at the top of `lib.rs` or `mod.rs`.
* Document parameters and return values in the description when non-obvious.
* Include `# Examples` sections for public API functions.
* Include `# Errors` sections for functions returning `Result`.
* Include `# Panics` sections for functions that can panic.

<!-- <example-documentation> -->
```rust
/// Processes the input data and returns the transformed result.
///
/// # Arguments
///
/// * `input` - Raw input bytes to process.
/// * `config` - Processing configuration.
///
/// # Returns
///
/// The processed output as a byte vector.
///
/// # Errors
///
/// Returns `ServiceError::InvalidInput` if the input cannot be parsed.
///
/// # Examples
///
/// ```
/// let result = process(&input, &config)?;
/// assert!(!result.is_empty());
/// ```
pub fn process(input: &[u8], config: &ProcessConfig) -> Result<Vec<u8>> {
    // ...
}
```
<!-- </example-documentation> -->

## Clippy and Formatting

### Clippy

* Run `cargo clippy` and resolve all warnings before committing.
* Do not suppress Clippy lints without documented justification.
* Use `#[allow(...)]` on specific items rather than crate-wide `#![allow(...)]` when suppression is necessary.

### Formatting

* Run `cargo fmt` before committing.
* Use default `rustfmt` configuration unless the project includes a `rustfmt.toml`.

## Additional Conventions

* Prefer `&str` over `String` in function parameters when ownership is not needed.
* Use `impl Into<String>` for constructors and builders accepting string arguments.
* Use `Cow<'_, str>` when a function may or may not need to allocate:

```rust
use std::borrow::Cow;

fn normalize_name(name: &str) -> Cow<'_, str> {
    if name.contains(' ') {
        Cow::Owned(name.replace(' ', "_"))
    } else {
        Cow::Borrowed(name)
    }
}
```

* Use iterators and combinators over manual loops where readability is maintained.
* Prefer `Vec<u8>` and slices over raw pointer manipulation.

## Patterns to Avoid

* `println!` or `eprintln!` in production code (use `tracing` macros).
* `unwrap()` or `expect()` in production paths without compile-time guarantees.
* Shared mutable state without synchronization primitives (`Mutex`, `RwLock`, `OnceLock`).
* Blocking operations inside async contexts (use `tokio::task::spawn_blocking`).
* Overly broad feature sets on dependencies (minimize with `default-features = false`).
* Global mutable statics without `OnceLock`, `LazyLock`, or equivalent.
* Suppressing Clippy lints without documented justification.
* `unsafe` blocks without a `// SAFETY:` comment explaining the invariant.

## Complete Example

Demonstrates naming, structure, error handling, async patterns, configuration, observability, and testing:

```rust
// Rust uses modules, not namespaces — see the mod declarations below.

use std::env;
use std::time::Duration;

use serde::{Deserialize, Serialize};
use thiserror::Error;
use tokio_retry::{strategy::ExponentialBackoff, Retry};
use tracing::{error, info};
use tracing_subscriber::filter::EnvFilter;

const ENDPOINT_VAR: &str = "SERVICE_ENDPOINT";
const INTERVAL_VAR: &str = "POLLING_INTERVAL";

// --- Error ---

pub type Result<T> = std::result::Result<T, ServiceError>;

#[derive(Error, Debug)]
pub enum ServiceError {
    #[error("Not found: {message}")]
    NotFound { message: String },

    #[error("Request failed: {message}")]
    Request { message: String },

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
}

impl ServiceError {
    pub fn not_found<S: Into<String>>(message: S) -> Self {
        Self::NotFound { message: message.into() }
    }

    pub fn request<S: Into<String>>(message: S) -> Self {
        Self::Request { message: message.into() }
    }
}

// --- Config ---

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppConfig {
    pub endpoint: String,
    #[serde(default = "default_interval")]
    pub polling_interval_secs: u64,
}

fn default_interval() -> u64 { 10 }

impl AppConfig {
    pub fn from_env() -> Self {
        Self {
            endpoint: env::var(ENDPOINT_VAR)
                .expect("SERVICE_ENDPOINT must be set"),
            polling_interval_secs: env::var(INTERVAL_VAR)
                .unwrap_or_else(|_| "10".to_string())
                .parse()
                .expect("POLLING_INTERVAL must be a valid u64"),
        }
    }
}

// --- Service ---

/// Polls an endpoint and processes responses.
pub struct PollingService {
    config: AppConfig,
    client: reqwest::Client,
}

impl PollingService {
    pub fn new(config: AppConfig) -> Self {
        Self {
            config,
            client: reqwest::Client::new(),
        }
    }

    /// Starts the polling loop.
    ///
    /// # Errors
    ///
    /// Returns `ServiceError::Request` on repeated fetch failures.
    pub async fn run(&self) -> Result<()> {
        let interval = Duration::from_secs(self.config.polling_interval_secs);

        loop {
            match self.fetch_with_retry().await {
                Ok(data) => info!(items = data.len(), "Fetched data"),
                Err(err) => error!(?err, "Fetch failed after retries"),
            }
            tokio::time::sleep(interval).await;
        }
    }

    async fn fetch_with_retry(&self) -> Result<Vec<u8>> {
        let strategy = ExponentialBackoff::from_millis(1000)
            .max_delay(Duration::from_secs(8))
            .take(3);

        Retry::spawn(strategy, || self.fetch()).await
    }

    async fn fetch(&self) -> Result<Vec<u8>> {
        let response = self.client
            .get(&self.config.endpoint)
            .send()
            .await
            .map_err(|e| ServiceError::request(e.to_string()))?;

        if !response.status().is_success() {
            return Err(ServiceError::request(
                format!("HTTP {}", response.status()),
            ));
        }

        response.bytes()
            .await
            .map(|b| b.to_vec())
            .map_err(|e| ServiceError::request(e.to_string()))
    }
}

// --- Entry Point ---

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let config = AppConfig::from_env();
    info!(endpoint = %config.endpoint, "Starting service");

    let service = PollingService::new(config);
    service.run().await
}
```
