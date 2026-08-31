# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Static checks over the local stack configuration shipped with this skill.

These tests parse the committed Compose and Collector documents and simulate the
declared attribute policy. They never start a container and never assert that a
running Collector behaves as configured; they assert only that the configuration
this skill ships declares the intended policy. Runtime behaviour is the subject
of `test_collector_carriers.py`, which is marked `slow` and does start one.
"""

from __future__ import annotations

import re
from typing import Any

import pytest
from _config_support import (
    COLLECTOR_PATH,
    COMPOSE_PATH,
    DIGEST_REFERENCE,
    EXAMPLES_DIR,
    MASK,
    OBSERVED_CONTENT_ATTRIBUTES,
    ConfigError,
    allowed_keys,
    blocked_values,
    load_yaml_file,
    load_yaml_text,
    overreaching_statements,
    prometheus_label_for,
    published_ports,
    redaction_policy,
    scrub_statements,
    shipped_consumers,
    simulate_redaction,
)


@pytest.fixture(scope="module")
def compose() -> dict[str, Any]:
    """The committed local Compose document."""
    return load_yaml_file(COMPOSE_PATH)


@pytest.fixture(scope="module")
def collector() -> dict[str, Any]:
    """The committed local Collector document."""
    return load_yaml_file(COLLECTOR_PATH)


class TestConfigurationLoading:
    """The shipped documents parse and expose the structures later tests read."""

    def test_given_the_committed_compose_when_it_is_parsed_then_services_is_a_non_empty_mapping(
        self,
        compose: dict[str, Any],
    ) -> None:
        # Act & Assert
        assert isinstance(compose.get("services"), dict)
        assert compose["services"], "compose declares no services"

    def test_given_a_yaml_list_document_when_it_is_loaded_then_config_error_is_raised(self) -> None:
        # Act & Assert
        with pytest.raises(ConfigError):
            load_yaml_text("- just\n- a list\n")

    def test_given_malformed_yaml_text_when_it_is_loaded_then_config_error_is_raised(self) -> None:
        # Act & Assert
        with pytest.raises(ConfigError):
            load_yaml_text("services: [unclosed\n")


class TestRedactionSimulation:
    """The policy simulator is fail-closed for keys and masking for values."""

    def test_given_a_key_outside_the_allow_list_when_redaction_runs_then_it_is_dropped(
        self,
    ) -> None:
        # Arrange
        allow = frozenset({"service.name"})

        # Act
        result = simulate_redaction({"service.name": "copilot", "prompt.text": "secret"}, allow)

        # Assert
        assert result == {"service.name": "copilot"}

    def test_given_an_allowed_key_when_its_value_matches_a_blocked_pattern_then_it_is_masked(
        self,
    ) -> None:
        # Arrange
        allow = frozenset({"http.url"})
        blocked = (re.compile(r"[0-9a-f]{40}"),)

        # Act
        result = simulate_redaction({"http.url": "a" * 40}, allow, blocked)

        # Assert
        assert result == {"http.url": MASK}

    def test_given_an_empty_allow_list_when_redaction_runs_then_every_attribute_is_dropped(
        self,
    ) -> None:
        # Act & Assert
        assert simulate_redaction({"any.key": "value"}, frozenset()) == {}


class TestTopology:
    """The Collector is the only OTLP ingress and LGTM is a private backend."""

    def test_given_the_collector_when_its_published_ports_are_read_then_otlp_binds_loopback_only(
        self,
        compose: dict[str, Any],
    ) -> None:
        # Act
        ports = published_ports(compose["services"]["otel-collector"])

        # Assert
        assert "127.0.0.1:4317:4317" in ports
        assert "127.0.0.1:4318:4318" in ports
        assert all(entry.startswith("127.0.0.1:") for entry in ports)

    def test_given_the_lgtm_service_when_its_ports_are_read_then_no_otlp_port_is_exposed(
        self,
        compose: dict[str, Any],
    ) -> None:
        # Act
        ports = published_ports(compose["services"]["lgtm"])

        # Assert
        assert not [entry for entry in ports if ":4317:" in entry or ":4318:" in entry]

    def test_given_the_lgtm_service_when_its_host_mappings_are_read_then_each_binds_loopback(
        self,
        compose: dict[str, Any],
    ) -> None:
        # Act & Assert
        assert all(
            entry.startswith("127.0.0.1:") for entry in published_ports(compose["services"]["lgtm"])
        )

    def test_given_declared_compose_networks_when_services_are_checked_then_both_join_them(
        self,
        compose: dict[str, Any],
    ) -> None:
        # Arrange
        declared = set(compose.get("networks") or {})

        # Act & Assert
        assert declared, "compose declares no explicit network"
        for name in ("otel-collector", "lgtm"):
            assert declared.issuperset(compose["services"][name]["networks"])

    def test_given_the_collector_exporters_when_endpoints_are_read_then_only_lgtm_4317_is_used(
        self, collector: dict[str, Any]
    ) -> None:
        # Arrange
        exporters = collector["exporters"]

        # Act
        endpoints = {
            config.get("endpoint") for config in exporters.values() if isinstance(config, dict)
        }

        # Assert
        assert endpoints == {"lgtm:4317"}


class TestRedactionPolicy:
    """The declared policy is fail-closed and reaches every pipeline."""

    def test_given_the_redaction_processor_when_its_policy_is_read_then_allow_all_keys_is_false(
        self,
        collector: dict[str, Any],
    ) -> None:
        # Act & Assert
        assert redaction_policy(collector).get("allow_all_keys") is False

    def test_given_the_collector_pipelines_when_each_is_read_then_all_three_include_redaction(
        self,
        collector: dict[str, Any],
    ) -> None:
        # Arrange
        pipelines = collector["service"]["pipelines"]

        # Act & Assert
        assert set(pipelines) == {"traces", "metrics", "logs"}
        for name, pipeline in pipelines.items():
            assert "redaction" in pipeline["processors"], f"{name} pipeline skips redaction"

    def test_given_shipped_consumers_when_the_allow_list_is_compared_then_no_read_key_is_dropped(
        self, collector: dict[str, Any]
    ) -> None:
        # Arrange
        consumers = shipped_consumers()
        allow = allowed_keys(collector)

        # Act
        missing = sorted(consumers.protected_attribute_keys() - allow)

        # Assert
        assert missing == [], f"the dashboard reads attributes the allow-list drops: {missing}"

    def test_given_dashboard_labels_when_allow_list_keys_are_normalized_then_none_is_uncovered(
        self, collector: dict[str, Any]
    ) -> None:
        """Compare in the OTLP-to-Prometheus direction, never the reverse.

        A label is derived from an attribute key by character substitution,
        and the substitution is not reversible. `copilot_chat_edit_source` has
        at least two plausible sources, so this asserts that some allow-listed
        key normalizes to each derived label rather than reconstructing one.
        """
        # Arrange
        consumers = shipped_consumers()
        covered = {prometheus_label_for(key) for key in allowed_keys(collector)}

        # Act
        uncovered = sorted(consumers.prometheus_labels - covered)

        # Assert
        assert uncovered == [], (
            f"the dashboard groups by labels no allow-listed key produces: {uncovered}. "
            "Add the source attribute or record the label as a known-empty gap; "
            "do not remove it from the derivation."
        )

    def test_given_shipped_consumers_when_metric_names_are_derived_then_token_usage_is_included(
        self,
    ) -> None:
        """The derivation has to see metric names, not only attributes.

        Without this, a scrub rule could be licensed against metric names on
        the grounds that no consumer was named for them.
        """
        # Act
        consumers = shipped_consumers()

        # Assert
        assert len(consumers.metric_names) > 15
        assert "gen_ai_client_token_usage_sum" in consumers.metric_names

    def test_given_shipped_consumers_when_span_matchers_are_derived_then_all_begin_invoke_agent(
        self,
    ) -> None:
        # Act
        consumers = shipped_consumers()

        # Assert
        assert consumers.span_name_matchers, "no TraceQL span-name matcher was derived"
        assert all(matcher.startswith("invoke_agent") for matcher in consumers.span_name_matchers)

    def test_given_shipped_consumers_when_trace_fields_are_derived_then_root_trace_name_appears(
        self,
    ) -> None:
        # Act & Assert
        assert "rootTraceName" in shipped_consumers().trace_fields

    def test_given_the_observed_content_attributes_when_the_allow_list_is_read_then_none_appear(
        self,
        collector: dict[str, Any],
    ) -> None:
        # Act & Assert
        assert not (OBSERVED_CONTENT_ATTRIBUTES & allowed_keys(collector))

    def test_given_unknown_future_attributes_when_redaction_runs_then_only_allowed_keys_survive(
        self, collector: dict[str, Any]
    ) -> None:
        # Arrange
        allow = allowed_keys(collector)
        emitted = {
            "service.name": "copilot-chat",
            "gen_ai.request.model": "gpt-5",
            # Neither key exists today. A delete-list would pass both through.
            "gen_ai.future.prompt_echo": "the user's entire prompt",
            "copilot_chat.unreleased_content": "a tool result",
        }

        # Act
        kept = simulate_redaction(emitted, allow, blocked_values(collector))

        # Assert
        assert set(kept) == {"service.name", "gen_ai.request.model"}

    def test_given_known_content_attributes_when_redaction_runs_then_nothing_is_kept(
        self,
        collector: dict[str, Any],
    ) -> None:
        # Arrange
        emitted = dict.fromkeys(OBSERVED_CONTENT_ATTRIBUTES, "plaintext content")

        # Act & Assert
        assert simulate_redaction(emitted, allowed_keys(collector), blocked_values(collector)) == {}

    def test_given_an_allowed_key_holding_a_github_token_when_redaction_runs_then_it_is_masked(
        self,
        collector: dict[str, Any],
    ) -> None:
        # Act
        kept = simulate_redaction(
            {"gen_ai.request.model": "ghp_" + "a" * 36},
            allowed_keys(collector),
            blocked_values(collector),
        )

        # Assert
        assert kept == {"gen_ai.request.model": MASK}

    def test_given_the_redaction_processor_when_its_summary_is_read_then_it_is_silent(
        self, collector: dict[str, Any]
    ) -> None:
        # Act & Assert
        assert redaction_policy(collector).get("summary") == "silent"


class TestGrafanaAccess:
    """Grafana requires a credential the operator supplies."""

    def test_given_lgtm_auth_settings_when_they_are_read_then_anonymous_is_off_and_login_form_on(
        self, compose: dict[str, Any]
    ) -> None:
        # Arrange
        environment = compose["services"]["lgtm"]["environment"]

        # Act & Assert
        assert str(environment["GF_AUTH_ANONYMOUS_ENABLED"]).lower() == "false"
        assert str(environment["GF_AUTH_DISABLE_LOGIN_FORM"]).lower() == "false"

    def test_given_lgtm_admin_credentials_when_compose_is_read_then_each_is_a_required_variable(
        self, compose: dict[str, Any]
    ) -> None:
        # Arrange
        environment = compose["services"]["lgtm"]["environment"]

        # Act & Assert
        for key, variable in (
            ("GF_SECURITY_ADMIN_USER", "COPILOT_OTEL_GRAFANA_USER"),
            ("GF_SECURITY_ADMIN_PASSWORD", "COPILOT_OTEL_GRAFANA_PASSWORD"),
        ):
            value = str(environment[key])
            assert value.startswith(f"${{{variable}:?"), f"{key} is not a required variable"

    def test_given_the_compose_file_text_when_it_is_scanned_then_no_default_password_is_present(
        self,
    ) -> None:
        # Arrange
        text = COMPOSE_PATH.read_text(encoding="utf-8")

        # Act & Assert
        assert "GF_SECURITY_ADMIN_PASSWORD: admin" not in text
        assert "admin:admin" not in text

    def test_given_the_dashboard_helper_when_its_source_is_read_then_both_variables_lack_defaults(
        self,
    ) -> None:
        # Arrange
        text = (EXAMPLES_DIR / "validate_dashboard.py").read_text(encoding="utf-8")

        # Act & Assert
        for variable in ("COPILOT_OTEL_GRAFANA_USER", "COPILOT_OTEL_GRAFANA_PASSWORD"):
            assert variable in text, f"{variable} is not read by the helper"
            # A default would make the helper usable against a credential the
            # operator never chose, which is the failure this pair exists to stop.
            assert f'"{variable}",' in text or f'"{variable}"\n' in text
            assert f'os.environ.get("{variable}",' not in text, f"{variable} has a default"
        assert "require_credentials(" in text, "credentials bypass the shared policy"


class TestContainerBounds:
    """The Collector's declared memory bound has to resolve against something.

    `memory_limiter` uses percentages, and those resolve against the cgroup
    limit when one exists and against total host memory when one does not.
    Without a declared limit, the configuration's stated bound is 80% of the
    developer's machine, in front of an ingress any local process can reach.
    """

    def test_given_the_collector_service_when_compose_is_read_then_a_memory_limit_is_declared(
        self,
        compose: dict[str, Any],
    ) -> None:
        # Act & Assert
        assert compose["services"]["otel-collector"]["mem_limit"] == "512m"

    def test_given_the_collector_service_when_compose_is_read_then_all_capabilities_are_dropped(
        self,
        compose: dict[str, Any],
    ) -> None:
        # Act & Assert
        assert compose["services"]["otel-collector"]["cap_drop"] == ["ALL"]

    def test_given_the_collector_service_when_compose_is_read_then_no_new_privileges_is_set(
        self,
        compose: dict[str, Any],
    ) -> None:
        # Act & Assert
        assert "no-new-privileges:true" in compose["services"]["otel-collector"]["security_opt"]

    def test_given_the_collector_service_when_compose_is_read_then_read_only_root_is_declared(
        self,
        compose: dict[str, Any],
    ) -> None:
        # Act & Assert
        assert compose["services"]["otel-collector"]["read_only"] is True


class TestCredentialShapeCoverage:
    """The value patterns are masking of recognizable shapes, not secret detection."""

    @pytest.mark.parametrize(
        "value",
        [
            "ghp_" + "a" * 36,
            "ASIA" + "B" * 16,
            "AKIA" + "C" * 16,
            "eyJhbGciOiJub25l.eyJzdWIiOiIxMjM0NTY3.",
            "AccountKey=" + "d" * 24,
            "sk-ant-" + "e" * 24,
            "AIza" + "f" * 35,
        ],
        ids=[
            "github-token",
            "aws-temporary-key-id",
            "aws-long-term-key-id",
            "unsigned-jwt",
            "azure-account-key",
            "anthropic-api-key",
            "google-api-key",
        ],
    )
    def test_given_credential_shaped_values_when_redaction_runs_then_each_shape_is_masked(
        self, collector: dict[str, Any], value: str
    ) -> None:
        # Act
        kept = simulate_redaction(
            {"gen_ai.request.model": value},
            allowed_keys(collector),
            blocked_values(collector),
        )

        # Assert
        assert kept == {"gen_ai.request.model": MASK}

    def test_given_an_ordinary_model_value_when_redaction_runs_then_it_is_left_unmasked(
        self,
        collector: dict[str, Any],
    ) -> None:
        """Without this, a pattern broad enough to mask everything would pass."""
        # Act
        kept = simulate_redaction(
            {"gen_ai.request.model": "gpt-5"},
            allowed_keys(collector),
            blocked_values(collector),
        )

        # Assert
        assert kept == {"gen_ai.request.model": "gpt-5"}


class TestScrubFailureDirection:
    """The scrub is fail-open per statement, and that is recorded where it lives."""

    def test_given_the_scrub_processor_when_its_error_mode_is_read_then_fail_open_is_documented(
        self, collector: dict[str, Any]
    ) -> None:
        # Act & Assert
        assert collector["processors"]["transform/scrub"]["error_mode"] == "ignore"
        text = COLLECTOR_PATH.read_text(encoding="utf-8")
        assert "fail-open per statement" in text, (
            "the asymmetry with the fail-closed allow-list is not recorded"
        )


class TestImagePinning:
    """Both images are pinned by immutable digest."""

    @pytest.mark.parametrize("service", ["otel-collector", "lgtm"])
    def test_given_each_compose_service_when_its_image_is_read_then_it_is_digest_pinned(
        self,
        compose: dict[str, Any],
        service: str,
    ) -> None:
        # Act & Assert
        assert DIGEST_REFERENCE.match(compose["services"][service]["image"])


class TestScrubStaysInsideTheInventory:
    """A scrub rule may not target anything a shipped consumer reads.

    The code review's own suggested fix for the ungoverned-carrier finding was
    to normalize span names. That would have broken three dashboard queries and
    the baseline helper's `rootTraceName` read. This check is oriented at the
    rules that were changed, because asserting that unchanged dashboard files
    still contain their strings cannot fail.
    """

    def test_given_the_collector_config_when_scrub_statements_are_read_then_they_are_not_empty(
        self,
        collector: dict[str, Any],
    ) -> None:
        # Act & Assert
        assert scrub_statements(collector), "the content scrub declares no statements"

    def test_given_the_shipped_scrub_statements_when_they_are_checked_then_no_overreach_is_found(
        self,
        collector: dict[str, Any],
    ) -> None:
        # Act
        findings = overreaching_statements(scrub_statements(collector), shipped_consumers())

        # Assert
        assert findings == [], f"a scrub rule targets telemetry a shipped panel reads: {findings}"

    def test_given_a_statement_that_rewrites_span_name_when_it_is_checked_then_it_is_reported(
        self,
    ) -> None:
        """The negative case. Without it this check could be vacuous."""
        # Arrange
        overreach = ['set(span.name, "[redacted]")']

        # Act & Assert
        assert overreaching_statements(overreach, shipped_consumers()) == [
            ('set(span.name, "[redacted]")', "span.name")
        ]

    def test_given_a_statement_deleting_a_read_attribute_when_it_is_checked_then_it_is_reported(
        self,
    ) -> None:
        # Arrange
        overreach = ['delete_key(span.attributes["gen_ai.request.model"], "x")']

        # Act
        findings = overreaching_statements(overreach, shipped_consumers())

        # Assert
        assert findings and findings[0][1] == "gen_ai.request.model"

    def test_given_a_where_clause_reading_a_protected_field_when_it_is_checked_then_it_is_allowed(
        self,
    ) -> None:
        """A `where` clause reads; it does not write."""
        # Arrange
        reading = ['set(span.status.message, "[redacted]") where span.name != ""']

        # Act & Assert
        assert overreaching_statements(reading, shipped_consumers()) == []


class TestExporterAlias:
    """The exporter uses the alias the pinned Collector asks for."""

    def test_given_the_collector_exporters_when_pipelines_are_read_then_none_uses_the_otlp_alias(
        self,
        collector: dict[str, Any],
    ) -> None:
        # Arrange
        exporters = set(collector["exporters"])

        # Act & Assert
        assert not any(name == "otlp" or name.startswith("otlp/") for name in exporters), (
            "the pinned Collector logs a deprecation warning once per signal for "
            "the `otlp` exporter alias; use `otlp_grpc`"
        )
        for name, pipeline in collector["service"]["pipelines"].items():
            assert set(pipeline["exporters"]) <= exporters, f"{name} names an undeclared exporter"

    def test_given_the_renamed_otlp_grpc_exporter_when_it_is_read_then_the_lgtm_hop_is_unchanged(
        self,
        collector: dict[str, Any],
    ) -> None:
        # Arrange
        exporter = collector["exporters"]["otlp_grpc/lgtm"]

        # Act & Assert
        assert exporter["endpoint"] == "lgtm:4317"
        assert exporter["tls"]["insecure"] is True
