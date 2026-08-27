# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Static checks over the Azure fleet templates.

These tests read the committed Bicep, Terraform, and Collector files as text and
YAML. Nothing here deploys, plans, or contacts Azure.
"""

from __future__ import annotations

import pathlib
import re

import pytest
import yaml
from _config_support import (
    COLLECTOR_PATH as LOCAL_COLLECTOR_PATH,
)
from _config_support import (
    DIGEST_REFERENCE,
    RELAY_COLLECTOR_PATH,
    RELAY_COMPOSE_PATH,
    load_yaml_file,
    redaction_policy,
    scrub_statements,
)

AZURE_DIR = pathlib.Path(__file__).resolve().parents[1] / "examples" / "azure"
COLLECTOR_PATH = AZURE_DIR / "otel-collector-config.yaml"
BICEP_PATH = AZURE_DIR / "main.bicep"
MAIN_TF_PATH = AZURE_DIR / "main.tf"
VARIABLES_TF_PATH = AZURE_DIR / "variables.tf"
OUTPUTS_TF_PATH = AZURE_DIR / "outputs.tf"

TEMPLATE_PATHS = [
    BICEP_PATH,
    MAIN_TF_PATH,
    VARIABLES_TF_PATH,
    OUTPUTS_TF_PATH,
    COLLECTOR_PATH,
    RELAY_COLLECTOR_PATH,
    RELAY_COMPOSE_PATH,
]

# The relay's runtime inputs, and the only values a rendered Compose document
# may carry. They are obvious non-secrets so a rendering failure cannot be
# mistaken for a leaked credential.
RELAY_SENTINELS = {
    "COPILOT_OTEL_FLEET_ENDPOINT": "https://sentinel-fleet.invalid",
    "COPILOT_OTEL_INGEST_TOKEN": "sentinel-token-not-a-credential",
    "COPILOT_OTEL_FLEET_CA_BUNDLE": "/sentinel/absolute/path/fleet-ca.pem",
}
RELAY_CA_MOUNT = "/run/copilot-otel/fleet-ca.pem"

# The managed-settings contract these relay files have to agree with.
ORG_DISTRIBUTION_PATH = (
    pathlib.Path(__file__).resolve().parents[1] / "references" / "org-distribution.md"
)

# Compose interpolation this skill uses: ${NAME:?message} for a required value
# and ${NAME} for a plain one.
COMPOSE_VARIABLE = re.compile(r"\$\{(?P<name>[A-Z0-9_]+)(?::\?(?P<message>[^}]*))?\}")

# Shapes that indicate a real credential rather than a placeholder or a
# reference to one.
SECRET_PATTERNS = (
    re.compile(r"InstrumentationKey=[0-9a-f]{8}-[0-9a-f]{4}", re.IGNORECASE),
    re.compile(r"gh[pousr]_[0-9A-Za-z]{16,}"),
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
)


@pytest.fixture(scope="module")
def collector() -> dict:
    return yaml.safe_load(COLLECTOR_PATH.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def local_collector() -> dict:
    """The local stack policy, which is this skill's minimization baseline."""
    return load_yaml_file(LOCAL_COLLECTOR_PATH)


@pytest.fixture(scope="module")
def relay() -> dict:
    """The shipped workstation relay Collector configuration."""
    return load_yaml_file(RELAY_COLLECTOR_PATH)


@pytest.fixture(scope="module")
def relay_compose() -> dict:
    """The relay Compose document with its required variables rendered.

    Rendering is what makes the mount and environment assertions mean
    something: an unrendered `${VAR:?...}` string satisfies any substring check
    while telling nothing about what the container would actually receive.
    """
    text = RELAY_COMPOSE_PATH.read_text(encoding="utf-8")
    rendered = COMPOSE_VARIABLE.sub(lambda match: RELAY_SENTINELS[match["name"]], text)
    return yaml.safe_load(rendered)


@pytest.fixture(scope="module")
def bicep() -> str:
    return BICEP_PATH.read_text(encoding="utf-8")


@pytest.fixture(scope="module")
def terraform() -> str:
    return "\n".join(path.read_text(encoding="utf-8") for path in (MAIN_TF_PATH, VARIABLES_TF_PATH))


class TestReceiverAuthentication:
    """The fleet receiver authenticates senders, in configuration and not in prose."""

    @pytest.mark.parametrize("protocol", ["http", "grpc"])
    def test_given_fleet_collector_when_reading_otlp_protocol_then_authenticator_is_bearertoken(
        self,
        collector: dict,
        protocol: str,
    ) -> None:
        # Arrange
        config = collector["receivers"]["otlp"]["protocols"][protocol]

        # Assert
        assert config["auth"]["authenticator"] == "bearertokenauth"

    def test_given_fleet_collector_when_reading_extensions_then_bearertokenauth_is_active(
        self,
        collector: dict,
    ) -> None:
        # Act & Assert
        assert "bearertokenauth" in collector["extensions"]
        assert "bearertokenauth" in collector["service"]["extensions"]

    def test_given_fleet_bearertokenauth_when_reading_token_then_value_is_env_reference(
        self,
        collector: dict,
    ) -> None:
        # Arrange
        token = collector["extensions"]["bearertokenauth"]["token"]

        # Assert
        assert token.startswith("${env:")

    def test_given_fleet_collector_text_when_scanning_comments_then_no_commented_bearertokenauth(
        self,
    ) -> None:
        # Arrange
        text = COLLECTOR_PATH.read_text(encoding="utf-8")

        # Act
        commented = [
            line
            for line in text.splitlines()
            if line.strip().startswith("#") and "bearertokenauth:" in line
        ]

        # Assert
        assert commented == [], "authentication is present only as a comment"


class TestReceiverTls:
    """TLS is configured, and its material comes from the environment."""

    @pytest.mark.parametrize("protocol", ["http", "grpc"])
    def test_given_fleet_collector_when_reading_protocol_tls_then_cert_and_key_are_env_refs(
        self,
        collector: dict,
        protocol: str,
    ) -> None:
        # Arrange
        tls = collector["receivers"]["otlp"]["protocols"][protocol]["tls"]

        # Assert
        assert tls["cert_file"].startswith("${env:")
        assert tls["key_file"].startswith("${env:")


class TestEnvironmentSeparation:
    """Separation comes from separate deployments, not from an attribute."""

    def test_given_bicep_when_reading_environment_param_then_it_is_declared_without_default(
        self,
        bicep: str,
    ) -> None:
        # Act & Assert
        assert re.search(r"^param environment string$", bicep, re.MULTILINE)
        assert "param environment string = " not in bicep, "environment must have no default"

    def test_given_terraform_when_reading_environment_variable_then_it_has_no_default(
        self,
        terraform: str,
    ) -> None:
        # Act & Assert
        assert 'variable "environment"' in terraform
        block = terraform.split('variable "environment"', 1)[1].split("\nvariable ", 1)[0]
        assert "default" not in block, "environment must have no default"

    def test_given_bicep_when_reading_resource_name_vars_then_each_interpolates_environment(
        self,
        bicep: str,
    ) -> None:
        # Act & Assert
        for name in ("workspaceName", "appInsightsName", "dashboardName"):
            line = next(line for line in bicep.splitlines() if line.startswith(f"var {name}"))
            assert "${environment}" in line

    def test_given_terraform_when_reading_resource_prefix_then_names_interpolate_environment(
        self,
        terraform: str,
    ) -> None:
        # Act & Assert
        assert 'resource_prefix = "${var.name_prefix}-${var.environment}"' in terraform
        assert "${local.resource_prefix}-copilot-logs" in terraform
        assert "${local.resource_prefix}-copilot-insights" in terraform

    def test_given_fleet_resource_processor_when_reading_environment_attribute_then_value_is_env(
        self, collector: dict
    ) -> None:
        # Arrange
        attributes = collector["processors"]["resource/fleet"]["attributes"]
        by_key = {entry["key"]: entry for entry in attributes}

        # Assert
        assert by_key["deployment.environment.name"]["value"].startswith("${env:")

    def test_given_all_templates_when_scanning_text_then_no_isolation_claim_for_attributes(
        self,
    ) -> None:
        # Act & Assert
        for path in TEMPLATE_PATHS:
            text = path.read_text(encoding="utf-8").lower()
            for claim in ("namespace provides isolation", "isolated by service.namespace"):
                assert claim not in text


class TestRetentionAndAccess:
    """Retention, caps, and reader scope agree across both templates."""

    def test_given_bicep_and_terraform_when_reading_retention_defaults_then_both_are_ninety_days(
        self,
        bicep: str,
        terraform: str,
    ) -> None:
        # Act & Assert
        assert "param retentionInDays int = 90" in bicep
        assert re.search(r'variable "retention_in_days"[\s\S]*?default\s*=\s*90', terraform)

    def test_given_bicep_and_terraform_when_reading_daily_cap_defaults_then_both_are_five_gb(
        self,
        bicep: str,
        terraform: str,
    ) -> None:
        # Act & Assert
        assert "param dailyQuotaGb int = 5" in bicep
        assert re.search(r'variable "daily_quota_gb"[\s\S]*?default\s*=\s*5', terraform)

    def test_given_bicep_and_terraform_when_reading_reader_assignment_then_it_is_conditional(
        self,
        bicep: str,
        terraform: str,
    ) -> None:
        # Act & Assert
        assert "if (!empty(readerPrincipalId))" in bicep
        assert 'count = var.reader_principal_id == "" ? 0 : 1' in terraform

    def test_given_bicep_and_terraform_when_reading_reader_scope_then_it_targets_the_workspace(
        self, bicep: str, terraform: str
    ) -> None:
        # Act & Assert
        assert "scope: workspace" in bicep
        assert "scope                = azurerm_log_analytics_workspace.this.id" in terraform

    def test_given_bicep_and_terraform_when_scanning_text_then_retention_is_a_deletion_policy(
        self, bicep: str, terraform: str
    ) -> None:
        # Act & Assert
        assert "deletion policy" in bicep.lower()
        assert "deletion policy" in terraform.lower()


class TestFleetPolicyParity:
    """The fleet filters at least as much as the local stack, on every signal.

    The destination here is a shared, retained workspace rather than one
    workstation's disposable container, so a fleet pipeline that filtered less
    than the local one would make the skill's pre-storage claims false in the
    place they matter most. Parity is asserted against the local document
    rather than restated, so drift in either file fails.
    """

    def test_given_fleet_collector_when_comparing_allowed_keys_to_local_then_they_match(
        self, collector: dict, local_collector: dict
    ) -> None:
        # Act & Assert
        assert (
            redaction_policy(collector)["allowed_keys"]
            == redaction_policy(local_collector)["allowed_keys"]
        )

    def test_given_fleet_collector_when_comparing_blocked_values_to_local_then_they_match(
        self, collector: dict, local_collector: dict
    ) -> None:
        # Act & Assert
        assert (
            redaction_policy(collector)["blocked_values"]
            == redaction_policy(local_collector)["blocked_values"]
        )

    def test_given_fleet_collector_when_reading_redaction_policy_then_it_is_fail_closed_and_silent(
        self,
        collector: dict,
    ) -> None:
        # Act
        policy = redaction_policy(collector)

        # Assert
        assert policy["allow_all_keys"] is False
        assert policy["summary"] == "silent"

    def test_given_fleet_collector_when_comparing_scrub_statements_to_local_then_they_match(
        self, collector: dict, local_collector: dict
    ) -> None:
        # Act & Assert
        assert scrub_statements(collector) == scrub_statements(local_collector)

    @pytest.mark.parametrize("signal", ["traces", "metrics", "logs"])
    def test_given_fleet_signal_pipeline_when_reading_processors_then_both_privacy_steps_present(
        self, collector: dict, signal: str
    ) -> None:
        # Arrange
        processors = collector["service"]["pipelines"][signal]["processors"]

        # Assert
        assert "redaction" in processors, f"{signal} reaches storage unfiltered"
        assert "transform/scrub" in processors, f"{signal} keeps ungoverned carriers"

    @pytest.mark.parametrize("signal", ["traces", "metrics", "logs"])
    def test_given_fleet_and_local_pipelines_when_comparing_privacy_order_then_it_is_unchanged(
        self, collector: dict, local_collector: dict, signal: str
    ) -> None:
        """The runtime carrier probe only substitutes definitions, not ordering."""
        # Arrange
        privacy = ("redaction", "transform/scrub")

        # Act
        fleet_order = [
            step
            for step in collector["service"]["pipelines"][signal]["processors"]
            if step in privacy
        ]
        local_order = [
            step
            for step in local_collector["service"]["pipelines"][signal]["processors"]
            if step in privacy
        ]

        # Assert
        assert fleet_order == local_order

    @pytest.mark.parametrize("signal", ["traces", "metrics", "logs"])
    def test_given_fleet_signal_pipeline_when_ordering_processors_then_filtering_precedes_export(
        self, collector: dict, signal: str
    ) -> None:
        # Arrange
        processors = collector["service"]["pipelines"][signal]["processors"]

        # Assert
        assert processors.index("memory_limiter") < processors.index("redaction")
        assert processors.index("transform/scrub") < processors.index("resource/fleet")
        assert processors.index("resource/fleet") < processors.index("batch")

    def test_given_fleet_collector_when_searching_for_strip_content_then_the_delete_list_is_absent(
        self,
        collector: dict,
    ) -> None:
        """A delete-list cannot fail closed on an attribute it has never seen."""
        # Act & Assert
        assert "attributes/strip-content" not in collector["processors"]
        for pipeline in collector["service"]["pipelines"].values():
            assert "attributes/strip-content" not in pipeline["processors"]


class TestRelayTopology:
    """The relay is reachable from this workstation and from nothing else."""

    def test_given_relay_collector_when_reading_otlp_protocols_then_only_http_is_declared(
        self,
        relay: dict,
    ) -> None:
        # Arrange
        protocols = relay["receivers"]["otlp"]["protocols"]

        # Assert
        assert set(protocols) == {"http"}, "a second ingress protocol would be unexercised"

    def test_given_relay_collector_when_reading_http_endpoint_then_it_binds_all_interfaces(
        self,
        relay: dict,
    ) -> None:
        """Host exposure is the port mapping's decision, exactly as the local stack does it."""
        # Act & Assert
        assert relay["receivers"]["otlp"]["protocols"]["http"]["endpoint"] == "0.0.0.0:4318"

    def test_given_relay_collector_when_reading_http_receiver_then_no_auth_is_required(
        self,
        relay: dict,
    ) -> None:
        """Both emitters export without one; requiring it here would drop everything."""
        # Act & Assert
        assert "auth" not in relay["receivers"]["otlp"]["protocols"]["http"]

    def test_given_rendered_relay_compose_when_reading_published_ports_then_all_bind_loopback(
        self,
        relay_compose: dict,
    ) -> None:
        # Arrange
        ports = [str(entry) for entry in relay_compose["services"]["otel-relay"]["ports"]]

        # Assert
        assert ports, "the relay publishes nothing"
        for entry in ports:
            assert entry.startswith("127.0.0.1:"), f"{entry} is reachable off this workstation"
            assert "::" not in entry

    def test_given_rendered_relay_compose_when_reading_port_mappings_then_only_4318_http_exists(
        self,
        relay_compose: dict,
    ) -> None:
        # Arrange
        ports = [str(entry) for entry in relay_compose["services"]["otel-relay"]["ports"]]

        # Assert
        assert "127.0.0.1:4318:4318" in ports
        assert not [entry for entry in ports if ":4317:" in entry], "gRPC is unsupported"


class TestRelayUpstream:
    """The upstream hop is authenticated and its certificate is verified."""

    def test_given_relay_fleet_exporter_when_reading_endpoint_then_it_is_an_env_reference(
        self,
        relay: dict,
    ) -> None:
        # Arrange
        exporter = relay["exporters"]["otlp_http/fleet"]

        # Assert
        assert exporter["endpoint"] == "${env:COPILOT_OTEL_FLEET_ENDPOINT}"

    def test_given_relay_fleet_exporter_when_reading_auth_then_bearertokenauth_uses_env_token(
        self,
        relay: dict,
    ) -> None:
        # Act & Assert
        assert relay["exporters"]["otlp_http/fleet"]["auth"]["authenticator"] == "bearertokenauth"
        assert relay["extensions"]["bearertokenauth"]["token"].startswith("${env:")
        assert "bearertokenauth" in relay["service"]["extensions"]

    def test_given_relay_fleet_exporter_when_reading_tls_then_it_verifies_the_mounted_ca(
        self,
        relay: dict,
    ) -> None:
        # Arrange
        tls = relay["exporters"]["otlp_http/fleet"]["tls"]

        # Assert
        assert tls["ca_file"] == RELAY_CA_MOUNT
        assert "insecure" not in tls, "the upstream hop must not opt out of verification"
        assert "insecure_skip_verify" not in tls

    def test_given_relay_pipelines_when_reading_exporters_then_only_the_fleet_exporter_is_used(
        self,
        relay: dict,
    ) -> None:
        # Act & Assert
        for name, pipeline in relay["service"]["pipelines"].items():
            assert pipeline["exporters"] == ["otlp_http/fleet"], f"{name} has a second destination"


class TestRelayPolicyParity:
    """Telemetry is minimized on the workstation that produced it."""

    def test_given_relay_collector_when_comparing_allowed_keys_to_local_then_they_match(
        self, relay: dict, local_collector: dict
    ) -> None:
        # Act & Assert
        assert (
            redaction_policy(relay)["allowed_keys"]
            == redaction_policy(local_collector)["allowed_keys"]
        )

    def test_given_relay_collector_when_comparing_blocked_values_to_local_then_they_match(
        self, relay: dict, local_collector: dict
    ) -> None:
        # Act & Assert
        assert (
            redaction_policy(relay)["blocked_values"]
            == redaction_policy(local_collector)["blocked_values"]
        )

    def test_given_relay_collector_when_comparing_scrub_statements_to_local_then_they_match(
        self, relay: dict, local_collector: dict
    ) -> None:
        # Act & Assert
        assert scrub_statements(relay) == scrub_statements(local_collector)

    @pytest.mark.parametrize("signal", ["traces", "metrics", "logs"])
    def test_given_relay_signal_pipeline_when_ordering_processors_then_filtering_precedes_batch(
        self, relay: dict, signal: str
    ) -> None:
        # Arrange
        processors = relay["service"]["pipelines"][signal]["processors"]

        # Assert
        assert processors.index("redaction") < processors.index("batch")
        assert processors.index("transform/scrub") < processors.index("batch")


class TestRelayRuntime:
    """The relay outlives VS Code, holds no committed credential, and is bounded."""

    def test_given_rendered_relay_compose_when_reading_the_image_then_it_is_digest_pinned(
        self,
        relay_compose: dict,
    ) -> None:
        # Act & Assert
        assert DIGEST_REFERENCE.match(relay_compose["services"]["otel-relay"]["image"])

    def test_given_rendered_relay_compose_when_reading_restart_policy_then_it_is_unless_stopped(
        self,
        relay_compose: dict,
    ) -> None:
        # Act & Assert
        assert relay_compose["services"]["otel-relay"]["restart"] == "unless-stopped"

    def test_given_rendered_relay_compose_when_reading_service_hardening_then_limits_are_applied(
        self,
        relay_compose: dict,
    ) -> None:
        # Arrange
        service = relay_compose["services"]["otel-relay"]

        # Assert
        assert service["read_only"] is True
        assert service["cap_drop"] == ["ALL"]
        assert "no-new-privileges:true" in service["security_opt"]
        assert service["mem_limit"] == "512m"

    @pytest.mark.parametrize("variable", sorted(RELAY_SENTINELS))
    def test_given_relay_compose_text_when_reading_a_runtime_variable_then_it_fails_without_value(
        self,
        variable: str,
    ) -> None:
        """A defaulted input would start a relay that silently discards everything."""
        # Arrange
        text = RELAY_COMPOSE_PATH.read_text(encoding="utf-8")

        # Act
        matches = [match for match in COMPOSE_VARIABLE.finditer(text) if match["name"] == variable]

        # Assert
        assert matches, f"{variable} is not read by the relay Compose document"
        for match in matches:
            assert match["message"], f"{variable} has no failure message and may default to empty"

    def test_given_rendered_relay_compose_when_reading_volumes_then_config_and_ca_are_read_only(
        self,
        relay_compose: dict,
    ) -> None:
        # Arrange
        volumes = [str(entry) for entry in relay_compose["services"]["otel-relay"]["volumes"]]

        # Act & Assert
        config_mount = next(entry for entry in volumes if entry.endswith("config.yaml:ro"))
        assert config_mount.startswith("./otel-collector-config.yaml:")
        ca_mount = next(entry for entry in volumes if RELAY_CA_MOUNT in entry)
        assert ca_mount == f"{RELAY_SENTINELS['COPILOT_OTEL_FLEET_CA_BUNDLE']}:{RELAY_CA_MOUNT}:ro"

    def test_given_rendered_relay_compose_when_reading_the_ca_mount_then_its_source_is_absolute(
        self,
        relay_compose: dict,
    ) -> None:
        """The skill ships no certificate authority, and could not ship a useful one."""
        # Arrange
        volumes = [str(entry) for entry in relay_compose["services"]["otel-relay"]["volumes"]]

        # Act
        ca_mount = next(entry for entry in volumes if RELAY_CA_MOUNT in entry)

        # Assert
        assert ca_mount.startswith("/"), "the bundle path must be absolute"
        assert not ca_mount.startswith("./")

    def test_given_rendered_relay_compose_when_scanning_services_then_only_relay_has_the_token(
        self,
        relay_compose: dict,
    ) -> None:
        # Arrange
        rendered = yaml.safe_dump(relay_compose)

        # Assert
        for service, definition in relay_compose["services"].items():
            environment = definition.get("environment") or {}
            if service != "otel-relay":
                assert RELAY_SENTINELS["COPILOT_OTEL_INGEST_TOKEN"] not in str(environment)
        assert rendered.count(RELAY_SENTINELS["COPILOT_OTEL_INGEST_TOKEN"]) == 1


class TestManagedSettingsMatchTheRelay:
    """The distributed managed block has to describe the relay that was shipped.

    An endpoint or protocol that drifts from the relay's single listener is not
    a documentation defect; it is a fleet that stops reporting after the
    managed settings change.
    """

    def test_given_org_distribution_doc_when_reading_managed_endpoint_then_it_matches_relay_port(
        self,
        relay_compose: dict,
    ) -> None:
        # Arrange
        text = ORG_DISTRIBUTION_PATH.read_text(encoding="utf-8")

        # Act & Assert
        assert '"endpoint": "http://127.0.0.1:4318"' in text
        ports = [str(entry) for entry in relay_compose["services"]["otel-relay"]["ports"]]
        assert "127.0.0.1:4318:4318" in ports

    def test_given_org_distribution_doc_when_reading_managed_protocol_then_it_matches_relay_http(
        self,
        relay: dict,
    ) -> None:
        # Arrange
        text = ORG_DISTRIBUTION_PATH.read_text(encoding="utf-8")

        # Assert
        assert '"protocol": "otlp-http"' in text
        assert set(relay["receivers"]["otlp"]["protocols"]) == {"http"}

    def test_given_org_distribution_json_block_when_reading_it_then_no_fleet_credential_appears(
        self,
    ) -> None:
        # Arrange
        text = ORG_DISTRIBUTION_PATH.read_text(encoding="utf-8")

        # Act
        block = text.split("```json", 1)[1].split("```", 1)[0]

        # Assert
        assert "headers" not in block, "the managed block must not distribute the fleet token"
        assert "Bearer" not in block

    def test_given_org_distribution_doc_when_searching_grpc_wording_then_it_is_named_unsupported(
        self,
    ) -> None:
        # Arrange
        text = ORG_DISTRIBUTION_PATH.read_text(encoding="utf-8").lower()

        # Assert
        assert "no grpc listener" in text or "there is no grpc listener" in text

    def test_given_org_distribution_doc_when_reading_rollout_prose_then_relay_comes_first(
        self,
    ) -> None:
        # Arrange
        text = ORG_DISTRIBUTION_PATH.read_text(encoding="utf-8").lower()

        # Assert
        assert "distributing this block" in text
        assert "sends no telemetry at all" in text
        assert "rolling back" in text or "rollback" in text


class TestStateAndSecrets:
    """No template carries a credential, and state sensitivity is stated."""

    @pytest.mark.parametrize("path", TEMPLATE_PATHS, ids=lambda p: p.name)
    def test_given_a_template_file_when_scanning_for_secret_patterns_then_none_match(
        self,
        path: pathlib.Path,
    ) -> None:
        # Arrange
        text = path.read_text(encoding="utf-8")

        # Assert
        for pattern in SECRET_PATTERNS:
            assert not pattern.search(text), f"{path.name} matches {pattern.pattern}"

    def test_given_terraform_outputs_when_reading_connection_string_then_it_is_marked_sensitive(
        self,
    ) -> None:
        # Arrange
        text = OUTPUTS_TF_PATH.read_text(encoding="utf-8")

        # Act
        block = text.split('output "connection_string"', 1)[1]

        # Assert
        assert "sensitive   = true" in block

    def test_given_main_terraform_when_reading_state_prose_then_sensitivity_is_documented(
        self,
    ) -> None:
        # Arrange
        text = MAIN_TF_PATH.read_text(encoding="utf-8").lower()

        # Assert
        assert "state file" in text
        assert "does not remove it from state" in text

    def test_given_bicep_outputs_when_reading_them_then_a_command_replaces_the_connection_string(
        self,
        bicep: str,
    ) -> None:
        # Act & Assert
        assert "output connectionStringCommand string" in bicep
        assert "output connectionString string =" not in bicep
