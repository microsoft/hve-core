---
applyTo: '**/*.py'
description: 'Required instructions for Python test code research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core'
---

# Python Test Instructions

Conventions for Python test code. All conventions from [python-script.instructions.md](python-script.instructions.md) apply.

## Test Framework

Use pytest with BDD-style naming. Structure each test with Arrange/Act/Assert (AAA) sections separated by blank lines and comments.

### Mocking Libraries

| Library                        | Usage                                                  |
|--------------------------------|--------------------------------------------------------|
| pytest-mock (`mocker` fixture) | Preferred for new projects and test migrations         |
| monkeypatch                    | Acceptable for simple attribute/environment patching   |
| unittest.mock (direct import)  | Existing projects only; migrate to mocker when editing |

## When to Use mocker vs monkeypatch

* `mocker.patch()` — replacing functions, methods, classes, or module attributes with controlled return values or side effects; verifying call counts and arguments.
* `monkeypatch.setattr()` — simple attribute overrides (constants, config values, environment variables) where return tracking is not needed.
* Direct `MagicMock()` import — acceptable for constructing pure test data stubs (mock objects used as constructor arguments, not as spy/assert targets).

## Test Naming

Test method format: `test_given_context_when_action_then_expected`

```text
test_given_valid_request_when_process_data_then_returns_parsed_response
test_given_empty_input_when_process_data_then_raises_value_error
test_given_missing_config_when_initialize_then_exits_with_error
```

Prefer one assertion per test. Related assertions validating the same behavior are acceptable. Do not verify logger mocks.

Use `@pytest.mark.parametrize` for data-driven tests with multiple input/output combinations.

## Test Organization

* File naming mirrors module under test with `test_` prefix (for example, `parser.py` → `test_parser.py`).
* Fixtures in `conftest.py` when shared across multiple test files.
* Class-based grouping optional; use when tests share setup logic.
* Group test methods by behavior, alphabetically within groups.
* Common mock setup in fixtures or class-level setup; specific setup in individual tests.

## pytest-mock Patterns

The `mocker` fixture from pytest-mock replaces direct `unittest.mock` usage. These patterns show each migration.

### mocker.patch() replacing @patch decorator

```python
# Before — unittest.mock
from unittest.mock import patch


@patch("myapp.service.fetch_data")
def test_process_uses_fetched_data(mock_fetch):
    mock_fetch.return_value = {"key": "value"}
    result = process()
    assert result == "value"


# After — pytest-mock
def test_process_uses_fetched_data(mocker):
    mock_fetch = mocker.patch("myapp.service.fetch_data", return_value={"key": "value"})
    result = process()
    assert result == "value"
    mock_fetch.assert_called_once()
```

### mocker.patch() replacing with patch() context manager

```python
# Before — unittest.mock
from unittest.mock import patch


def test_service_calls_endpoint():
    with patch("myapp.client.post") as mock_post:
        mock_post.return_value.status_code = 200
        response = send_request()
    assert response.status_code == 200


# After — pytest-mock
def test_service_calls_endpoint(mocker):
    mock_post = mocker.patch("myapp.client.post")
    mock_post.return_value.status_code = 200
    response = send_request()
    assert response.status_code == 200
```

### mocker.patch.dict() replacing @patch.dict

```python
# Before — unittest.mock
from unittest.mock import patch


@patch.dict("os.environ", {"API_KEY": "test-key"})
def test_config_reads_env():
    config = load_config()
    assert config.api_key == "test-key"


# After — pytest-mock
def test_config_reads_env(mocker):
    mocker.patch.dict("os.environ", {"API_KEY": "test-key"})
    config = load_config()
    assert config.api_key == "test-key"
```

### mocker.patch.object() replacing patch.object()

```python
# Before — unittest.mock
from unittest.mock import patch

from myapp.service import DataService


@patch.object(DataService, "connect")
def test_service_connects(mock_connect):
    mock_connect.return_value = True
    svc = DataService()
    assert svc.connect() is True


# After — pytest-mock
from myapp.service import DataService


def test_service_connects(mocker):
    mock_connect = mocker.patch.object(DataService, "connect", return_value=True)
    svc = DataService()
    assert svc.connect() is True
    mock_connect.assert_called_once()
```

### mocker.MagicMock() and mocker.AsyncMock() for spy targets

Use `mocker.MagicMock()` and `mocker.AsyncMock()` when constructing mock objects that serve as spy targets for call assertion:

```python
def test_handler_delegates_to_processor(mocker):
    mock_processor = mocker.MagicMock()
    handler = RequestHandler(processor=mock_processor)
    handler.handle({"id": 1})
    mock_processor.process.assert_called_once_with({"id": 1})


async def test_async_handler_awaits_processor(mocker):
    mock_processor = mocker.AsyncMock()
    handler = AsyncRequestHandler(processor=mock_processor)
    await handler.handle({"id": 1})
    mock_processor.process.assert_awaited_once_with({"id": 1})
```

### Direct MagicMock() import for test data stubs

Direct `MagicMock()` import stays as-is when constructing pure test data stubs that are not spy/assert targets:

```python
from unittest.mock import MagicMock


def test_formatter_accepts_any_writer():
    # Arrange
    stub_writer = MagicMock()
    stub_writer.encoding = "utf-8"
    formatter = OutputFormatter(writer=stub_writer)

    # Act
    result = formatter.format("hello")

    # Assert
    assert result == "hello"
```

## Complete Example

A full test class using the mocker fixture with AAA structure:

```python
import pytest  # noqa: F811

from myapp.processor import DataProcessor
from myapp.service import DataService


class TestDataProcessor:
    @pytest.fixture()
    def mock_service(self, mocker):
        return mocker.patch.object(DataService, "fetch", return_value={"status": "ok", "value": 42})

    @pytest.fixture()
    def processor(self):
        return DataProcessor(service=DataService())

    def test_given_valid_response_when_process_then_returns_value(self, processor, mock_service):
        # Act
        result = processor.process()

        # Assert
        assert result == 42
        mock_service.assert_called_once()

    def test_given_error_response_when_process_then_raises(self, processor, mocker):
        # Arrange
        mocker.patch.object(DataService, "fetch", side_effect=ConnectionError("timeout"))

        # Act & Assert
        with pytest.raises(ConnectionError, match="timeout"):
            processor.process()

    @pytest.mark.parametrize(
        ("status", "expected"),
        [
            ("ok", 42),
            ("pending", 0),
        ],
    )
    def test_given_status_when_process_then_returns_expected(self, mocker, status, expected):
        # Arrange
        mocker.patch.object(DataService, "fetch", return_value={"status": status, "value": expected})
        processor = DataProcessor(service=DataService())

        # Act
        result = processor.process()

        # Assert
        assert result == expected
```
