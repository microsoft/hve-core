# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Behavioral tests for the shared helper input policy.

Every rejection case asserts that the refusal happens before any request or
write, which is the property that matters: a guard that rejects after the
side effect is not a guard.
"""

from __future__ import annotations

import io
import ipaddress
import json
import os
import pathlib
import subprocess
import sys
import urllib.request

import inspect_metrics
import pytest
import validate_dashboard
import verify
from _input_policy import (
    DEFAULT_ALLOWED_PORTS,
    PolicyError,
    check_url,
    contain_path,
    is_loopback_host,
    open_url,
    origin_of,
    require_credentials,
)

EXAMPLES_DIR = pathlib.Path(__file__).resolve().parents[1] / "examples"

# Address literals, so these tests exercise the policy rather than whatever
# DNS answers on the machine running them. 93.184.216.34 is globally routable
# and 10.0.0.7 is not; no test opens a connection to either.
GLOBAL_ADDRESS = "93.184.216.34"
PRIVATE_ADDRESS = "10.0.0.7"


@pytest.fixture
def resolves(monkeypatch: pytest.MonkeyPatch):
    """Pin what each name resolves to, so the rule under test is the policy.

    Resolution is the thing this policy now depends on, which makes real DNS a
    dependency of the test rather than a subject of it. An unroutable name and
    a name that answers with a routable address are both failures worth
    asserting, and neither is reliably reproducible against a real resolver.
    """

    def apply(mapping: dict[str, list[str]]) -> None:
        def fake(host: str) -> tuple:
            try:
                return (ipaddress.ip_address(host.strip("[]")),)
            except ValueError:
                pass
            if host not in mapping:
                raise PolicyError(f"refusing '{host}': it does not resolve")
            return tuple(ipaddress.ip_address(value) for value in mapping[host])

        monkeypatch.setattr("_input_policy.resolve_addresses", fake)

    return apply


class TestScheme:
    """Only http and https are addressable."""

    @pytest.mark.parametrize(
        "url",
        [
            "file:///etc/passwd",
            "ftp://localhost/data",
            "data:text/plain,hello",
            "gopher://localhost:70/",
            "//localhost:3000/api",
        ],
    )
    def test_given_a_non_http_scheme_url_when_check_url_runs_then_it_raises_policy_error(
        self,
        url: str,
    ) -> None:
        # Act & Assert
        with pytest.raises(PolicyError):
            check_url(url)

    def test_given_a_loopback_http_url_when_check_url_runs_then_the_hostname_is_returned(
        self,
    ) -> None:
        # Act & Assert
        assert check_url("http://localhost:3000/api/health").hostname == "localhost"


class TestAuthority:
    """Credentials, missing hosts, and malformed authorities are refused."""

    @pytest.mark.parametrize(
        "url",
        [
            "http://user@localhost:3000/",
            "http://user:pass@localhost:3000/",
            "http://:pass@localhost:3000/",
        ],
    )
    def test_given_a_url_with_userinfo_when_check_url_runs_then_it_refuses_credentials(
        self,
        url: str,
    ) -> None:
        # Act & Assert
        with pytest.raises(PolicyError, match="credentials"):
            check_url(url)

    def test_given_a_url_without_a_host_when_check_url_runs_then_it_raises_policy_error(
        self,
    ) -> None:
        # Act & Assert
        with pytest.raises(PolicyError):
            check_url("http:///api/health")

    def test_given_a_url_with_a_malformed_port_when_check_url_runs_then_it_raises_policy_error(
        self,
    ) -> None:
        # Act & Assert
        with pytest.raises(PolicyError):
            check_url("http://localhost:notaport/")


class TestPorts:
    """Local requests stay on the stack's own ports."""

    @pytest.mark.parametrize("port", sorted(DEFAULT_ALLOWED_PORTS))
    def test_given_a_default_allowed_stack_port_when_check_url_runs_then_the_port_is_preserved(
        self,
        port: int,
    ) -> None:
        # Act & Assert
        assert check_url(f"http://127.0.0.1:{port}/").port == port

    @pytest.mark.parametrize("port", [22, 80, 443, 8080, 5432])
    def test_given_a_loopback_url_on_another_port_when_check_url_runs_then_it_is_refused(
        self,
        port: int,
    ) -> None:
        # Act & Assert
        with pytest.raises(PolicyError, match="local port"):
            check_url(f"http://127.0.0.1:{port}/")


class TestRemoteOptIn:
    """A remote target needs an explicit opt-in, TLS, and a globally routable address."""

    def test_given_a_remote_host_without_opt_in_when_check_url_runs_then_it_refuses_as_non_loopback(
        self,
        resolves,
    ) -> None:
        # Arrange
        resolves({"grafana.example.com": [GLOBAL_ADDRESS]})

        # Act & Assert
        with pytest.raises(PolicyError, match="non-loopback"):
            check_url("https://grafana.example.com/")

    def test_given_a_globally_routable_host_with_opt_in_when_check_url_runs_then_https_is_accepted(
        self,
        resolves,
    ) -> None:
        # Arrange
        resolves({"grafana.example.com": [GLOBAL_ADDRESS]})

        # Act & Assert
        assert check_url("https://grafana.example.com/", allow_remote=True).scheme == "https"

    def test_given_an_http_remote_host_with_opt_in_when_check_url_runs_then_it_refuses_plaintext(
        self,
        resolves,
    ) -> None:
        # Arrange
        resolves({"grafana.example.com": [GLOBAL_ADDRESS]})

        # Act & Assert
        with pytest.raises(PolicyError, match="plaintext"):
            check_url("http://grafana.example.com/", allow_remote=True)

    def test_given_an_opted_in_private_name_when_check_url_runs_then_non_global_is_refused(
        self, resolves
    ) -> None:
        """The opt-in permits a remote target, not a route back into the network."""
        # Arrange
        resolves({"grafana.example.com": [PRIVATE_ADDRESS]})

        # Act & Assert
        with pytest.raises(PolicyError, match="non-global"):
            check_url("https://grafana.example.com/", allow_remote=True)


class TestHostResolution:
    """A name is classified by where it resolves, not by how it is spelled."""

    def test_given_localhost_resolving_globally_when_it_is_classified_then_it_is_not_loopback(
        self,
        resolves,
    ) -> None:
        # Arrange
        resolves({"localhost": [GLOBAL_ADDRESS]})

        # Act & Assert
        assert is_loopback_host("localhost") is False
        with pytest.raises(PolicyError, match="non-loopback"):
            check_url("http://localhost:3000/")

    def test_given_a_name_resolving_to_loopback_and_global_when_it_is_checked_then_it_is_refused(
        self,
        resolves,
    ) -> None:
        """Treating a mixed answer as local would permit a connection off machine."""
        # Arrange
        resolves({"split.example": ["127.0.0.1", GLOBAL_ADDRESS]})

        # Act & Assert
        assert is_loopback_host("split.example") is False
        with pytest.raises(PolicyError, match="loopback and non-loopback"):
            check_url("http://split.example:3000/")

    def test_given_a_name_that_does_not_resolve_when_check_url_runs_then_it_is_refused(
        self,
        resolves,
    ) -> None:
        # Arrange
        resolves({})

        # Act & Assert
        with pytest.raises(PolicyError, match="does not resolve"):
            check_url("http://nowhere.invalid:3000/")

    @pytest.mark.parametrize("literal", ["127.0.0.1", "[::1]"])
    def test_given_a_loopback_address_literal_when_it_is_classified_then_no_resolver_is_needed(
        self,
        literal: str,
    ) -> None:
        # Act & Assert
        assert is_loopback_host(literal) is True


class TestRedirects:
    """Policy is re-applied to redirect targets, not only the original URL."""

    def _handler(self) -> urllib.request.HTTPRedirectHandler:
        opener = open_url.__globals__["_PolicyRedirectHandler"]
        return opener(allow_remote=False, allowed_ports=DEFAULT_ALLOWED_PORTS)

    def test_given_a_loopback_request_when_it_redirects_off_loopback_then_it_is_refused(
        self,
    ) -> None:
        # Arrange
        request = urllib.request.Request("http://localhost:3000/api")

        # Act & Assert
        with pytest.raises(PolicyError, match="non-loopback"):
            self._handler().redirect_request(
                request, None, 302, "Found", {}, f"http://{GLOBAL_ADDRESS}/"
            )

    def test_given_a_loopback_request_when_it_redirects_to_a_file_url_then_the_scheme_is_refused(
        self,
    ) -> None:
        # Arrange
        request = urllib.request.Request("http://localhost:3000/api")

        # Act & Assert
        with pytest.raises(PolicyError, match="scheme"):
            self._handler().redirect_request(request, None, 302, "Found", {}, "file:///etc/passwd")

    def test_given_a_loopback_request_when_it_redirects_to_port_22_then_the_local_port_is_refused(
        self,
    ) -> None:
        # Arrange
        request = urllib.request.Request("http://localhost:3000/api")

        # Act & Assert
        with pytest.raises(PolicyError, match="local port"):
            self._handler().redirect_request(
                request, None, 302, "Found", {}, "http://localhost:22/"
            )

    def test_given_a_disallowed_url_when_open_url_runs_then_it_refuses_before_calling_the_opener(
        self,
        monkeypatch,
    ) -> None:
        # Arrange
        opened: list[str] = []
        monkeypatch.setattr(
            urllib.request.OpenerDirector,
            "open",
            lambda self, *a, **k: opened.append("opened"),
        )

        # Act
        with pytest.raises(PolicyError):
            open_url("http://evil.example.com/")

        # Assert
        assert opened == [], "a refused URL still reached the opener"


class TestProxyNeutralization:
    """A permitted loopback request is not routed through an ambient proxy.

    `build_opener` adds to the default handler chain, so the default
    `ProxyHandler` is installed unless an empty one is passed explicitly.
    `proxy_bypass` does not exempt loopback, so without that the request goes
    to whatever `HTTP_PROXY` names -- carrying the Grafana Basic credential
    that `validate_dashboard` attaches. `no_proxy` is cleared here on purpose:
    an environment where it already covers loopback would pass either way.
    """

    def _built_opener(self, monkeypatch) -> urllib.request.OpenerDirector:
        monkeypatch.setenv("HTTP_PROXY", "http://proxy.invalid:3128")
        monkeypatch.setenv("http_proxy", "http://proxy.invalid:3128")
        monkeypatch.setenv("NO_PROXY", "")
        monkeypatch.setenv("no_proxy", "")
        captured: list[urllib.request.OpenerDirector] = []
        monkeypatch.setattr(
            urllib.request.OpenerDirector,
            "open",
            lambda self, *a, **k: captured.append(self),
        )
        open_url("http://127.0.0.1:3000/api/health")
        return captured[0]

    def test_given_proxy_env_variables_when_open_url_builds_an_opener_then_no_proxy_is_configured(
        self,
        monkeypatch,
    ) -> None:
        # Act
        opener = self._built_opener(monkeypatch)

        # Assert
        configured = {
            scheme: target
            for handler in opener.handlers
            if isinstance(handler, urllib.request.ProxyHandler)
            for scheme, target in handler.proxies.items()
        }
        assert configured == {}, f"open_url would proxy loopback traffic to {configured}"

    def test_given_open_url_when_it_builds_an_opener_then_the_policy_redirect_handler_is_kept(
        self,
        monkeypatch,
    ) -> None:
        # Arrange
        policy_handler = open_url.__globals__["_PolicyRedirectHandler"]

        # Act
        opener = self._built_opener(monkeypatch)

        # Assert
        assert any(isinstance(handler, policy_handler) for handler in opener.handlers), (
            "the redirect allow-list re-check and cross-origin credential stripping were dropped"
        )


class TestPathContainment:
    """A configurable path cannot escape its root."""

    def test_given_a_relative_path_when_contain_path_runs_then_it_resolves_inside_the_root(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Act & Assert
        assert contain_path("snapshot.json", tmp_path) == (tmp_path / "snapshot.json").resolve()

    def test_given_a_traversal_path_when_contain_path_runs_then_it_is_refused(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Act & Assert
        with pytest.raises(PolicyError):
            contain_path("../../etc/passwd", tmp_path)

    def test_given_an_absolute_path_outside_the_root_when_contain_path_runs_then_it_is_refused(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Arrange
        outside = tmp_path.parent / "outside.json"

        # Act & Assert
        with pytest.raises(PolicyError):
            contain_path(outside, tmp_path)

    def test_given_a_symlink_pointing_outside_the_root_when_contain_path_runs_then_it_is_refused(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Arrange
        root = tmp_path / "root"
        root.mkdir()
        target = tmp_path / "outside"
        target.mkdir()
        link = root / "escape"
        try:
            link.symlink_to(target, target_is_directory=True)
        except (OSError, NotImplementedError):
            pytest.skip("symlink creation is not permitted in this environment")

        # Act & Assert
        with pytest.raises(PolicyError):
            contain_path(link / "snapshot.json", root)

    def test_given_the_root_itself_when_contain_path_runs_then_the_resolved_root_is_returned(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Act & Assert
        assert contain_path(tmp_path, tmp_path) == tmp_path.resolve()


class TestCredentials:
    """Missing configuration is reported as configuration, before any request."""

    def test_given_both_credential_env_vars_missing_when_they_are_required_then_both_are_named(
        self,
        monkeypatch,
    ) -> None:
        # Arrange
        monkeypatch.delenv("COPILOT_OTEL_GRAFANA_USER", raising=False)
        monkeypatch.delenv("COPILOT_OTEL_GRAFANA_PASSWORD", raising=False)

        # Act
        with pytest.raises(PolicyError) as excinfo:
            require_credentials("COPILOT_OTEL_GRAFANA_USER", "COPILOT_OTEL_GRAFANA_PASSWORD")

        # Assert
        assert "COPILOT_OTEL_GRAFANA_USER" in str(excinfo.value)
        assert "COPILOT_OTEL_GRAFANA_PASSWORD" in str(excinfo.value)

    def test_given_only_the_password_var_missing_when_they_are_required_then_it_is_named(
        self,
        monkeypatch,
    ) -> None:
        # Arrange
        monkeypatch.setenv("COPILOT_OTEL_GRAFANA_USER", "admin")
        monkeypatch.delenv("COPILOT_OTEL_GRAFANA_PASSWORD", raising=False)

        # Act & Assert
        with pytest.raises(PolicyError, match="COPILOT_OTEL_GRAFANA_PASSWORD"):
            require_credentials("COPILOT_OTEL_GRAFANA_USER", "COPILOT_OTEL_GRAFANA_PASSWORD")

    def test_given_an_empty_password_value_when_they_are_required_then_it_counts_as_missing(
        self,
        monkeypatch,
    ) -> None:
        # Arrange
        monkeypatch.setenv("COPILOT_OTEL_GRAFANA_USER", "admin")
        monkeypatch.setenv("COPILOT_OTEL_GRAFANA_PASSWORD", "")

        # Act & Assert
        with pytest.raises(PolicyError, match="COPILOT_OTEL_GRAFANA_PASSWORD"):
            require_credentials("COPILOT_OTEL_GRAFANA_USER", "COPILOT_OTEL_GRAFANA_PASSWORD")

    def test_given_both_variables_set_when_they_are_required_then_the_pair_is_returned_in_order(
        self,
        monkeypatch,
    ) -> None:
        # Arrange
        monkeypatch.setenv("COPILOT_OTEL_GRAFANA_USER", "operator")
        monkeypatch.setenv("COPILOT_OTEL_GRAFANA_PASSWORD", "chosen-by-the-user")

        # Act & Assert
        assert require_credentials(
            "COPILOT_OTEL_GRAFANA_USER", "COPILOT_OTEL_GRAFANA_PASSWORD"
        ) == ("operator", "chosen-by-the-user")


def run_helper(
    name: str, args: list[str], env_overrides: dict[str, str]
) -> subprocess.CompletedProcess[str]:
    """Run a bundled helper in its own process with a controlled environment.

    A refusal exits before argparse and before any socket is opened. Running
    the helpers as processes is what proves the wiring; importing the policy
    module directly would only re-test the module these tests already cover.
    """
    env = dict(os.environ)
    env.update(env_overrides)
    env["COPILOT_OTEL_ALLOW_REMOTE"] = "0"
    return subprocess.run(
        [sys.executable, str(EXAMPLES_DIR / name), *args],
        capture_output=True,
        text=True,
        timeout=60,
        env=env,
        cwd=str(EXAMPLES_DIR),
        check=False,
    )


class TestHelperWiring:
    """Each helper actually calls the shared policy, not merely imports it.

    Without these, deleting a `contain_path` call from a helper would leave the
    policy tests above green while restoring the exact write this change closed.
    """

    def test_given_an_escaping_snapshot_path_when_baseline_captures_then_nothing_is_written(
        self, tmp_path: pathlib.Path
    ) -> None:
        # Arrange
        target = tmp_path / "escaped-snapshot.json"

        # Act
        result = run_helper("baseline.py", ["capture"], {"COPILOT_OTEL_BASELINE": str(target)})

        # Assert
        assert result.returncode != 0
        assert "refusing a path outside" in (result.stderr + result.stdout)
        assert not target.exists(), "a refused snapshot path was still written"

    def test_given_a_traversal_snapshot_path_when_baseline_captures_then_it_exits_nonzero(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Act
        result = run_helper(
            "baseline.py", ["capture"], {"COPILOT_OTEL_BASELINE": "../../escaped.json"}
        )

        # Assert
        assert result.returncode != 0
        assert "refusing a path outside" in (result.stderr + result.stdout)

    def test_given_a_malformed_dashboard_when_the_helper_runs_then_it_reports_without_a_traceback(
        self, tmp_path: pathlib.Path
    ) -> None:
        # Arrange
        broken = tmp_path / "generated-dashboard.json"
        broken.write_text("{not json", encoding="utf-8")

        # Act
        result = run_helper(
            "validate_dashboard.py",
            [str(broken)],
            {
                "COPILOT_OTEL_GRAFANA_USER": "operator",
                "COPILOT_OTEL_GRAFANA_PASSWORD": "chosen-by-the-user",
            },
        )

        # Assert
        assert result.returncode == 1
        combined = result.stderr + result.stdout
        assert "not valid JSON" in combined
        assert "Traceback" not in combined

    def test_given_a_non_loopback_grafana_endpoint_when_the_helper_runs_then_it_is_refused(
        self,
    ) -> None:
        # Act
        result = run_helper(
            "validate_dashboard.py",
            [],
            {
                "COPILOT_OTEL_GRAFANA": f"https://{GLOBAL_ADDRESS}:3000",
                "COPILOT_OTEL_GRAFANA_USER": "operator",
                "COPILOT_OTEL_GRAFANA_PASSWORD": "chosen-by-the-user",
            },
        )

        # Assert
        assert result.returncode != 0
        assert "non-loopback" in (result.stderr + result.stdout)

    def test_given_a_non_loopback_prometheus_endpoint_when_the_helper_runs_then_it_is_refused(
        self,
    ) -> None:
        """The Prometheus override was previously unchecked entirely."""
        # Act
        result = run_helper(
            "validate_dashboard.py",
            [],
            {
                "COPILOT_OTEL_PROMETHEUS": f"http://{GLOBAL_ADDRESS}:9090",
                "COPILOT_OTEL_GRAFANA_USER": "operator",
                "COPILOT_OTEL_GRAFANA_PASSWORD": "chosen-by-the-user",
            },
        )

        # Assert
        assert result.returncode != 0
        assert "non-loopback" in (result.stderr + result.stdout)

    def test_given_empty_grafana_credentials_when_the_helper_runs_then_both_variables_are_named(
        self,
    ) -> None:
        # Act
        result = run_helper(
            "validate_dashboard.py",
            [],
            {"COPILOT_OTEL_GRAFANA_USER": "", "COPILOT_OTEL_GRAFANA_PASSWORD": ""},
        )

        # Assert
        assert result.returncode != 0
        combined = result.stderr + result.stdout
        assert "COPILOT_OTEL_GRAFANA_USER" in combined
        assert "COPILOT_OTEL_GRAFANA_PASSWORD" in combined


class TestDashboardSelection:
    """A generated dashboard is the normal subject, not an intrusion.

    Confining the argument to the installed skill directory made the workflow
    the README documents impossible: the dashboard worth checking is usually
    one that was just produced somewhere else. What replaces the containment
    check is a controlled failure for every way a selected file can be wrong.
    """

    def _dashboard(self) -> dict:
        return {"panels": [{"title": "one", "type": "row"}]}

    def test_given_a_dashboard_outside_the_skill_when_load_dashboard_runs_then_it_is_loaded(
        self, tmp_path: pathlib.Path
    ) -> None:
        # Arrange
        generated = tmp_path / "generated.json"
        generated.write_text(json.dumps(self._dashboard()), encoding="utf-8")

        # Act & Assert
        assert validate_dashboard.load_dashboard(str(generated)) == self._dashboard()

    def test_given_a_relative_path_when_load_dashboard_runs_then_it_resolves_against_the_cwd(
        self, tmp_path: pathlib.Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        (tmp_path / "generated.json").write_text(json.dumps(self._dashboard()), encoding="utf-8")
        monkeypatch.chdir(tmp_path)

        # Act & Assert
        assert validate_dashboard.load_dashboard("generated.json") == self._dashboard()

    def test_given_no_dashboard_argument_when_load_dashboard_runs_then_the_bundled_one_is_loaded(
        self,
    ) -> None:
        # Act & Assert
        assert validate_dashboard.load_dashboard(None)["panels"]

    def test_given_a_path_to_no_file_when_load_dashboard_runs_then_it_reports_a_missing_dashboard(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Act & Assert
        with pytest.raises(PolicyError, match="no dashboard at"):
            validate_dashboard.load_dashboard(str(tmp_path / "absent.json"))

    def test_given_a_directory_path_when_load_dashboard_runs_then_it_reports_a_directory(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Act & Assert
        with pytest.raises(PolicyError, match="not a dashboard file"):
            validate_dashboard.load_dashboard(str(tmp_path))

    def test_given_a_file_of_invalid_json_when_load_dashboard_runs_then_it_reports_invalid_json(
        self,
        tmp_path: pathlib.Path,
    ) -> None:
        # Arrange
        broken = tmp_path / "broken.json"
        broken.write_text("{not json", encoding="utf-8")

        # Act & Assert
        with pytest.raises(PolicyError, match="not valid JSON"):
            validate_dashboard.load_dashboard(str(broken))

    @pytest.mark.parametrize("content", ["[]", '{"title": "no panels"}', '{"panels": {}}'])
    def test_given_json_without_a_panels_array_when_load_dashboard_runs_then_it_reports_no_panels(
        self, tmp_path: pathlib.Path, content: str
    ) -> None:
        # Arrange
        candidate = tmp_path / "not-a-dashboard.json"
        candidate.write_text(content, encoding="utf-8")

        # Act & Assert
        with pytest.raises(PolicyError, match="no panels array"):
            validate_dashboard.load_dashboard(str(candidate))


def _json_response(payload: dict) -> io.BytesIO:
    """A minimal stand-in for what open_url returns."""
    return io.BytesIO(json.dumps(payload).encode("utf-8"))


# Shaped to satisfy every reader in validate_dashboard at once: a Grafana
# import result, a Prometheus query result, a Prometheus label listing, a Tempo
# search result, and a TraceQL metrics result.
_ANY_STORE_RESPONSE = {
    "status": "success",
    "url": "/d/copilot-otel/copilot",
    "data": {"result": []},
    "traces": [],
    "series": [],
}


class TestGrafanaCredentialLiveness:
    """`verify.py` reports which admin credential is live, not only whether ours works.

    Grafana applies `GF_SECURITY_ADMIN_*` only when it creates its database, so
    a stack on a pre-existing database can be running on `admin`/`admin` while
    the configured pair was supplied and ignored. A check that tried only the
    configured pair would report that as a mismatch rather than as a live
    default credential, which is the condition worth failing the run for.
    """

    @pytest.fixture(autouse=True)
    def _isolated_results(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(verify, "results", [])

    def _probe(self, monkeypatch: pytest.MonkeyPatch, answers: dict) -> None:
        monkeypatch.setattr(
            verify, "grafana_accepts", lambda user, password: answers.get((user, password), False)
        )

    def _outcome(self, name: str) -> tuple[bool, str]:
        return next((ok, detail) for recorded, ok, detail in verify.results if recorded == name)

    def _configure(self, monkeypatch: pytest.MonkeyPatch, user: str, password: str) -> None:
        monkeypatch.setenv("COPILOT_OTEL_GRAFANA_USER", user)
        monkeypatch.setenv("COPILOT_OTEL_GRAFANA_PASSWORD", password)

    def test_given_only_the_configured_credential_works_when_grafana_is_checked_then_both_pass(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        self._configure(monkeypatch, "operator", "chosen-by-the-user")
        self._probe(monkeypatch, {("operator", "chosen-by-the-user"): True})

        # Act
        verify.check_grafana_credentials()

        # Assert
        assert self._outcome("configured grafana credential works")[0] is True
        assert self._outcome("grafana default credential inactive")[0] is True

    def test_given_admin_admin_works_when_grafana_is_checked_then_the_default_check_fails(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        self._configure(monkeypatch, "operator", "chosen-by-the-user")
        self._probe(monkeypatch, {("admin", "admin"): True})

        # Act
        verify.check_grafana_credentials()

        # Assert
        ok, detail = self._outcome("grafana default credential inactive")
        assert ok is False
        assert "admin/admin authenticates" in detail

    def test_given_admin_admin_works_when_grafana_is_checked_then_the_configured_check_fails(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        self._configure(monkeypatch, "operator", "chosen-by-the-user")
        self._probe(monkeypatch, {("admin", "admin"): True})

        # Act
        verify.check_grafana_credentials()

        # Assert
        ok, detail = self._outcome("configured grafana credential works")
        assert ok is False
        assert "database predates this password" in detail

    def test_given_an_unanswered_probe_when_grafana_is_checked_then_no_answer_is_reported(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        self._configure(monkeypatch, "operator", "chosen-by-the-user")
        monkeypatch.setattr(verify, "grafana_accepts", lambda user, password: None)

        # Act
        verify.check_grafana_credentials()

        # Assert
        assert "no answer from Grafana" in self._outcome("configured grafana credential works")[1]

    def test_given_unset_grafana_variables_when_grafana_is_checked_then_they_are_named_not_probed(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        monkeypatch.delenv("COPILOT_OTEL_GRAFANA_USER", raising=False)
        monkeypatch.delenv("COPILOT_OTEL_GRAFANA_PASSWORD", raising=False)
        self._probe(monkeypatch, {})

        # Act
        verify.check_grafana_credentials()

        # Assert
        ok, detail = self._outcome("configured grafana credential works")
        assert ok is False
        assert "are not both set" in detail

    def test_given_the_default_pair_is_configured_when_grafana_is_checked_then_it_fails(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        self._configure(monkeypatch, "admin", "admin")
        self._probe(monkeypatch, {("admin", "admin"): True})

        # Act
        verify.check_grafana_credentials()

        # Assert
        ok, detail = self._outcome("grafana default credential inactive")
        assert ok is False
        assert "is the image default" in detail


class TestGrafanaCredentialScope:
    """The Grafana credential reaches Grafana and nothing else.

    The defect this replaces was a shared request builder that attached the
    header unconditionally. Five of the six call sites address Prometheus or
    Tempo, neither of which authenticates against Grafana, so every panel
    replay handed a third-party store an admin credential for a fourth.
    """

    def test_given_no_authorization_when_build_request_runs_then_the_header_is_absent(self) -> None:
        # Act
        request = validate_dashboard.build_request("http://localhost:9090/api/v1/query")

        # Assert
        assert "Authorization" not in request.headers

    def test_given_an_authorization_value_when_build_request_runs_then_the_header_carries_it(
        self,
    ) -> None:
        # Act
        request = validate_dashboard.build_request(
            "http://localhost:3000/api/dashboards/db",
            b"{}",
            "POST",
            authorization="Basic supplied-at-the-call-site",
        )

        # Assert
        assert request.headers["Authorization"] == "Basic supplied-at-the-call-site"

    def test_given_a_full_dashboard_walk_when_the_tool_runs_then_only_grafana_is_authorized(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Drive the real tool and inspect every request it actually builds.

        This is the assertion that covers all six call sites rather than a
        representative one: the shipped dashboard is walked, every panel query
        is issued, and each resulting request object is inspected.
        """
        # Arrange
        sent: list[urllib.request.Request] = []

        def fake_open_url(request, **kwargs):  # noqa: ANN001, ANN202
            sent.append(request)
            return _json_response(_ANY_STORE_RESPONSE)

        monkeypatch.setattr(validate_dashboard, "open_url", fake_open_url)
        monkeypatch.setenv("COPILOT_OTEL_GRAFANA_USER", "operator")
        monkeypatch.setenv("COPILOT_OTEL_GRAFANA_PASSWORD", "chosen-by-the-user")
        monkeypatch.delenv("COPILOT_OTEL_ALLOW_REMOTE", raising=False)

        # Act
        assert validate_dashboard.main([]) == 0

        # Assert
        authorized = [r for r in sent if "Authorization" in r.headers]
        assert len(sent) > 1, "the dashboard walk issued no store queries"
        assert len(authorized) == 1, (
            f"exactly one request may carry the Grafana credential; {len(authorized)} did"
        )
        assert authorized[0].full_url.startswith("http://localhost:3000/")
        for request in sent:
            if request is authorized[0]:
                continue
            assert "Authorization" not in request.headers, (
                f"{request.full_url} received the Grafana credential"
            )


class TestRedirectCredentialHandling:
    """A redirect may not carry a credential to an origin it was not issued for."""

    def _handler(self, *, allow_remote: bool = False) -> urllib.request.HTTPRedirectHandler:
        handler = open_url.__globals__["_PolicyRedirectHandler"]
        return handler(allow_remote=allow_remote, allowed_ports=DEFAULT_ALLOWED_PORTS)

    def _redirect(
        self, start: str, target: str, *, allow_remote: bool = False
    ) -> urllib.request.Request:
        request = urllib.request.Request(start)
        request.add_header("Authorization", "Basic issued-for-the-original-origin")
        request.add_header("Proxy-Authorization", "Basic proxy")
        request.add_header("Cookie", "session=abc")
        request.add_header("Accept", "application/json")
        return self._handler(allow_remote=allow_remote).redirect_request(
            request, None, 302, "Found", {}, target
        )

    @pytest.mark.parametrize("header", ["Authorization", "Proxy-Authorization", "Cookie"])
    def test_given_a_credential_header_when_a_redirect_changes_the_local_port_then_it_is_dropped(
        self, header: str
    ) -> None:
        # Act
        redirected = self._redirect("http://localhost:3000/api", "http://localhost:9090/api")

        # Assert
        assert not any(name.lower() == header.lower() for name in redirected.headers)

    def test_given_a_credential_header_when_a_redirect_stays_on_the_same_origin_then_it_is_kept(
        self,
    ) -> None:
        # Act
        redirected = self._redirect("http://localhost:3000/api", "http://localhost:3000/other")

        # Assert
        assert redirected.headers["Authorization"] == "Basic issued-for-the-original-origin"

    def test_given_a_redirect_adding_the_default_https_port_when_it_is_handled_then_it_is_kept(
        self,
        resolves,
    ) -> None:
        """`https://h/x` and `https://h:443/y` are one origin, not two."""
        # Arrange
        resolves({"grafana.example.com": [GLOBAL_ADDRESS]})

        # Act
        redirected = self._redirect(
            "https://grafana.example.com/api",
            "https://grafana.example.com:443/other",
            allow_remote=True,
        )

        # Assert
        assert redirected.headers["Authorization"] == "Basic issued-for-the-original-origin"

    def test_given_a_redirect_to_a_different_remote_host_when_it_is_handled_then_it_is_dropped(
        self,
        resolves,
    ) -> None:
        # Arrange
        resolves(
            {
                "grafana.example.com": [GLOBAL_ADDRESS],
                "someone-else.example.com": [GLOBAL_ADDRESS],
            }
        )

        # Act
        redirected = self._redirect(
            "https://grafana.example.com/api",
            "https://someone-else.example.com/api",
            allow_remote=True,
        )

        # Assert
        assert "Authorization" not in redirected.headers

    def test_given_a_redirect_to_a_different_remote_port_when_it_is_handled_then_it_is_dropped(
        self,
        resolves,
    ) -> None:
        # Arrange
        resolves({"grafana.example.com": [GLOBAL_ADDRESS]})

        # Act
        redirected = self._redirect(
            "https://grafana.example.com/api",
            "https://grafana.example.com:9090/api",
            allow_remote=True,
        )

        # Assert
        assert "Authorization" not in redirected.headers

    def test_given_an_accept_header_when_a_redirect_changes_the_origin_then_it_survives(
        self,
    ) -> None:
        # Act
        redirected = self._redirect("http://localhost:3000/api", "http://localhost:9090/api")

        # Assert
        assert redirected.headers["Accept"] == "application/json"

    def test_given_the_credential_headers_when_a_redirect_changes_the_origin_then_none_remain(
        self,
    ) -> None:
        # Act
        redirected = self._redirect("http://localhost:3000/api", "http://localhost:9090/api")

        # Assert
        remaining = {name.lower() for name in redirected.headers}
        assert remaining.isdisjoint({"authorization", "proxy-authorization", "cookie"})


class TestOriginNormalization:
    """Origin comparison is the mechanism the redirect rule rests on."""

    @pytest.mark.parametrize(
        ("one", "other"),
        [
            ("http://h/a", "http://h:80/b"),
            ("https://h/a", "https://h:443/b"),
            ("http://H/a", "http://h/b"),
        ],
    )
    def test_given_urls_differing_only_by_default_port_or_case_when_origin_of_runs_then_they_match(
        self,
        one: str,
        other: str,
    ) -> None:
        # Act & Assert
        assert origin_of(one) == origin_of(other)

    @pytest.mark.parametrize(
        ("one", "other"),
        [
            ("http://h/a", "https://h/a"),
            ("http://h/a", "http://other/a"),
            ("http://h:3000/a", "http://h:9090/a"),
        ],
    )
    def test_given_urls_differing_by_scheme_host_or_port_when_origin_of_runs_then_they_differ(
        self,
        one: str,
        other: str,
    ) -> None:
        # Act & Assert
        assert origin_of(one) != origin_of(other)


class TestPolicyRoutedHelpers:
    """Both previously bypassing helpers reach the network only through policy.

    Their endpoints are loopback constants today, so the bypass was not
    currently exploitable. It was a maintenance defect: a later endpoint change
    in either file would have escaped every control the other helpers inherit.
    """

    @pytest.mark.parametrize("module", [verify, inspect_metrics], ids=lambda m: m.__name__)
    def test_given_a_patched_open_url_when_the_helper_calls_api_then_it_goes_through_policy(
        self, module, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        opened: list[str] = []

        def fake_open_url(url, **kwargs):  # noqa: ANN001, ANN202
            opened.append(url)
            return _json_response({"data": []})

        monkeypatch.setattr(module, "open_url", fake_open_url)

        # Act
        module.api(module.PROM, "/api/v1/label/__name__/values")

        # Assert
        assert opened == ["http://localhost:9090/api/v1/label/__name__/values"]

    @pytest.mark.parametrize(
        "name", ["verify.py", "inspect_metrics.py", "validate_dashboard.py", "baseline.py"]
    )
    def test_given_a_bundled_helper_source_when_it_is_scanned_then_no_direct_urlopen_appears(
        self,
        name: str,
    ) -> None:
        # Arrange
        source = (EXAMPLES_DIR / name).read_text(encoding="utf-8")

        # Act & Assert
        assert "urlopen(" not in source, (
            f"{name} opens a URL directly; every helper must go through open_url "
            "so scheme, authority, port, redirect, and remote-opt-in rules apply"
        )
