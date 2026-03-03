---
applyTo: '**/*.rs'
description: 'Required instructions for Rust test code research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core'
---

# Rust Test Instructions

Conventions for Rust test code. All conventions from [rust.instructions.md](rust.instructions.md) apply, including naming, error handling, and module structure.

## Test Module Placement

Place unit tests in `#[cfg(test)] mod tests` within the source file they exercise:

<!-- <example-tests> -->
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn given_valid_input_parse_returns_config() {
        let json = r#"{"endpoint": "https://example.com"}"#;
        let config: AppConfig = serde_json::from_str(json).unwrap();
        assert_eq!(config.polling_interval_secs, 10);
    }

    #[tokio::test]
    async fn when_endpoint_available_fetch_returns_data() {
        let service = PollingService::new(AppConfig::from_env());
        let result = service.fetch().await;
        assert!(result.is_ok(), "fetch should succeed when endpoint is available");
    }
}
```
<!-- </example-tests> -->

## Test Naming

Test method format: `given_context_when_action_then_expected` or descriptive snake_case that reads as a behavior statement.

```text
given_valid_input_parse_returns_config
when_endpoint_unavailable_send_returns_error
parses_empty_payload_as_default
```

Prefer one assertion per test. Related assertions validating the same behavior are acceptable.

## Mocking Libraries

| Library    | Usage                                                   |
|------------|---------------------------------------------------------|
| `mockall`  | Preferred for trait-based mocking                       |
| `wiremock` | HTTP server mocking in async tests                      |
| `mockito`  | Lightweight HTTP mocking for synchronous or async tests |

Use `mockall` to generate mock implementations from traits via `#[automock]`:

```rust
use mockall::automock;

// Application types — defined in your crate (see rust.instructions.md)
pub struct Item {
    pub id: String,
}

// Uses the module-scoped Result alias from rust.instructions.md
#[automock]
pub trait Repository: Send + Sync {
    fn find_by_id(&self, id: &str) -> Result<Option<Item>>;
}

pub struct ItemService {
    repo: Box<dyn Repository>,
}

impl ItemService {
    pub fn new(repo: Box<dyn Repository>) -> Self {
        Self { repo }
    }

    pub fn get(&self, id: &str) -> Result<Option<Item>> {
        self.repo.find_by_id(id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use mockall::predicate::*;

    #[test]
    fn given_existing_item_service_returns_it() {
        let mut mock = MockRepository::new();
        mock.expect_find_by_id()
            .with(eq("42"))
            .returning(|_| Ok(Some(Item { id: "42".into() })));

        let service = ItemService::new(Box::new(mock));
        let result = service.get("42").unwrap();
        assert_eq!(result.unwrap().id, "42");
    }
}
```

Use `wiremock` to mock HTTP servers in async tests:

```rust
use wiremock::{MockServer, Mock, ResponseTemplate};
use wiremock::matchers::method;

#[tokio::test]
async fn when_api_returns_ok_fetch_succeeds() {
    let mock_server = MockServer::start().await;

    Mock::given(method("GET"))
        .respond_with(ResponseTemplate::new(200).set_body_string(r#"{"id": "1"}"#))
        .mount(&mock_server)
        .await;

    let client = reqwest::Client::new();
    let response = client.get(mock_server.uri()).send().await.unwrap();
    assert_eq!(response.status(), 200);
}
```

Add test dependencies to `[dev-dependencies]` in `Cargo.toml`:

```toml
[dev-dependencies]
mockall = "0.13"
reqwest = { version = "0.12", features = ["json"] }
tokio = { version = "1", features = ["macros", "rt"] }
wiremock = "0.6"
```

## Test Data Patterns

Use builder functions or fixture helpers for test data rather than repeating inline construction:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    fn sample_config() -> AppConfig {
        AppConfig {
            endpoint: "https://example.com".into(),
            polling_interval_secs: 10,
        }
    }

    #[test]
    fn given_custom_interval_config_uses_override() {
        let config = AppConfig {
            polling_interval_secs: 30,
            ..sample_config()
        };
        assert_eq!(config.polling_interval_secs, 30);
    }
}
```

Inline construction is acceptable for simple one-field tests where a builder adds no clarity.

## Integration Tests

Place integration tests in the `tests/` directory at the crate root. Each file in `tests/` compiles as a separate crate with access to the library's public API only:

```rust
// tests/polling_integration.rs
use my_service::AppConfig;

#[tokio::test]
async fn given_valid_config_service_starts() {
    let config = AppConfig {
        endpoint: "https://example.com".into(),
        polling_interval_secs: 1,
    };
    assert!(!config.endpoint.is_empty());
}
```

## Test Conventions

* Use `#[tokio::test]` for async tests.
* Prefer assertion messages that explain intent: `assert!(result.is_ok(), "should parse valid JSON")`.
* Use builder functions or fixture helpers for test data rather than repeating inline construction.
* Place integration tests in the `tests/` directory at the crate root.

## Complete Example

Types referenced below (`AppConfig`, `ServiceError`, `Result` alias) are defined in [rust.instructions.md](rust.instructions.md).

```rust
#[cfg(test)]
mod tests {
    use super::*;

    // Fixture helper — see Test Data Patterns
    fn sample_config() -> AppConfig {
        AppConfig {
            endpoint: "https://example.com".into(),
            polling_interval_secs: 10,
        }
    }

    #[test]
    fn given_defaults_config_has_ten_second_interval() {
        let config = sample_config();
        assert_eq!(config.polling_interval_secs, 10);
    }

    #[test]
    fn service_error_not_found_formats_message() {
        let err = ServiceError::not_found("item 42");
        assert_eq!(err.to_string(), "Not found: item 42");
    }

    #[tokio::test]
    async fn when_fetch_fails_error_contains_status() {
        let config = sample_config();
        let service = PollingService::new(config);
        let result = service.fetch().await;
        assert!(result.is_err(), "fetch should fail with unreachable endpoint");
    }
}
```
