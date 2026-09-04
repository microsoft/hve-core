# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Runtime carrier map for the shipped local Collector configuration.

Starts the pinned Collector, sends payloads that place a unique marker in every
OTLP carrier the signal model can transport, and records what the shipped
policy does to each one. The recorded map is the citable evidence behind the
minimization claims in `SECURITY.md` and the references, and it is asserted as
a regression boundary, so a configuration or image change that opens a carrier
fails here.

Absence alone proves nothing: a marker can be missing because policy dropped it
or because the exporter never renders that field. Every run is therefore paired
with a negative control that removes the content-minimization processors from
the same configuration. A marker the control does not render is `unobservable`,
never `governed`.
"""

from __future__ import annotations

import base64
import copy
import json
import os
import pathlib
import platform
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
from collections.abc import Mapping
from dataclasses import dataclass, field

import pytest
import yaml

SKILL_ROOT = pathlib.Path(__file__).resolve().parents[1]
COLLECTOR_PATH = SKILL_ROOT / "examples" / "otel-collector-local.yaml"
COMPOSE_PATH = SKILL_ROOT / "examples" / "compose.yaml"
FLEET_COLLECTOR_PATH = SKILL_ROOT / "examples" / "azure" / "otel-collector-config.yaml"

# Which shipped document supplies the content-minimization processors under
# test. The fleet document exports to a shared, retained workspace, so its
# policy needs the same carrier-level evidence as the local one rather than a
# static claim that the two files look alike.
LOCAL_POLICY = "local"
FLEET_POLICY = "fleet"
POLICY_SOURCES = (LOCAL_POLICY, FLEET_POLICY)

# The probe runs the same image the stack runs. Read from compose.yaml rather
# than restated here, so a pin bump cannot leave this harness testing an image
# the stack no longer uses.
COLLECTOR_SERVICE = "otel-collector"

# Every processor whose job is to remove or replace content. The negative
# control removes all of them, because validating the instrument against only
# one of them would let the other hide a marker and make an unobservable
# carrier look governed.
CONTENT_PROCESSORS = ("redaction", "transform/scrub")

# A skipped run produces no evidence. That is tolerable on a contributor's
# machine and not tolerable anywhere the run's result is cited: `SECURITY.md`
# and the references attribute their minimization claims to this module, so a
# lane that quietly stopped starting the Collector would keep reporting green
# while those claims lost their backing. The lane that owns this evidence says
# so explicitly through this variable; no ambient signal turns strictness on,
# because a generic runner that never selected these tests should not inherit
# their runtime prerequisites.
STRICT_RUNTIME_ENV = "COPILOT_OTEL_STRICT_RUNTIME"
_FALSE_VALUES = frozenset({"", "0", "false", "no", "off"})

# This module starts containers and pulls a pinned image. Selecting it is a
# deliberate act by a lane that provisions those prerequisites.
pytestmark = pytest.mark.slow

MASK = "****"
SCRUB = "[redacted]"

GOVERNED = "governed"
MASKED = "masked"
PASSED_THROUGH = "passed-through"
UNOBSERVABLE = "unobservable"

# How a carrier is handled, for the reader. Classification is observed;
# mechanism is declared, and the two are checked against each other only in the
# sense that a carrier with no mechanism must be passed-through.
ALLOW_LIST = "allow-list"
BLOCKED_VALUES = "blocked_values"
CONTENT_SCRUB = "content scrub"
NO_MECHANISM = "none"

# The probed receiver protocol. OTLP/gRPC is published by the same shipped
# configuration and is not probed here; it is carried as a gap.
PROBED_PROTOCOL = "otlp/http"
UNPROBED_PROTOCOL = "otlp/grpc"

_BYTES_MARKER_PLAINTEXT = b"CARRIERMARKERLOGBODYBYTES"
# The exporter renders a bytes body as base64, so the observable marker is the
# encoded form rather than the plaintext.
BYTES_MARKER = base64.b64encode(_BYTES_MARKER_PLAINTEXT).decode("ascii")

# Attributes a shipped detection control reads that the allow-list had been
# dropping. Survival is asserted per key, because an allow-list entry that is
# present in the YAML and still dropped at runtime is the same class of
# unbacked claim this module exists to prevent.
RESTORED_DETECTION_KEYS: dict[str, str] = {
    "session.id": "RESTOREDMARKERSESSIONID",
    "gen_ai.token.type": "RESTOREDMARKERTOKENTYPE",
    "copilot_chat.edit_source": "RESTOREDMARKEREDITSOURCEFLAT",
    "copilot_chat.edit.source": "RESTOREDMARKEREDITSOURCEDOTTED",
}


@dataclass(frozen=True)
class Carrier:
    """One OTLP content carrier, its probe marker, and its observed handling."""

    name: str
    marker: str
    expected: str
    # The declared mechanism responsible for the expected classification.
    mechanism: str = NO_MECHANISM
    # Present only for a carrier whose value is replaced rather than removed.
    # The literal the exporter must render when replacement occurred.
    masked_signature: str | None = None
    note: str = ""


# The observed carrier map.
#
# Recorded from execution against the pinned Collector with the shipped
# configuration, and validated by the negative control in the same run. This is
# a baseline, not an aspiration: rebaselining a `governed` entry to
# `passed-through` is a policy decision that needs its own evidence.
CARRIERS: tuple[Carrier, ...] = (
    # --- Attributes. Fail-closed everywhere the allow-list reaches. ---
    Carrier("resource attribute", "CARRIERMARKERRESOURCEATTR", GOVERNED, ALLOW_LIST),
    Carrier("instrumentation scope attribute", "CARRIERMARKERSCOPEATTR", GOVERNED, ALLOW_LIST),
    Carrier("span attribute", "CARRIERMARKERSPANATTR", GOVERNED, ALLOW_LIST),
    Carrier("span event attribute", "CARRIERMARKERSPANEVENTATTR", GOVERNED, ALLOW_LIST),
    Carrier("log record attribute", "CARRIERMARKERLOGATTR", GOVERNED, ALLOW_LIST),
    Carrier("metric datapoint attribute", "CARRIERMARKERDATAPOINTATTR", GOVERNED, ALLOW_LIST),
    Carrier(
        "log body, map",
        "CARRIERMARKERLOGBODYMAP",
        GOVERNED,
        ALLOW_LIST,
        note="A map body is treated as an attribute set and reduced to the "
        "allow-listed subset. The other body shapes are not, which is why the "
        "content scrub covers them.",
    ),
    # --- Attributes the allow-list cannot reach, and neither can anything
    # --- else in this distribution.
    Carrier(
        "span link attribute",
        "CARRIERMARKERLINKATTR",
        PASSED_THROUGH,
        NO_MECHANISM,
        note="The redaction processor does not traverse span links, and OTTL "
        "has no spanlink context and refuses to index links, so no processor "
        "in this distribution can reach it. Recorded as a gap.",
    ),
    Carrier(
        "span link trace state",
        "CARRIERMARKERLINKTRACESTATE",
        PASSED_THROUGH,
        NO_MECHANISM,
        note="Unreachable for the same reason as the link attribute above.",
    ),
    Carrier(
        "metric exemplar filtered attribute",
        "CARRIERMARKEREXEMPLARATTR",
        PASSED_THROUGH,
        NO_MECHANISM,
        note="Not traversed by the allow-list. Assigning to datapoint.exemplars "
        "parses but has no effect. Recorded as a gap.",
    ),
    # --- Values replaced by blocked_values. ---
    Carrier(
        "allow-listed attribute value matching blocked_values",
        "CARRIERMARKERMASKSPANATTR",
        MASKED,
        BLOCKED_VALUES,
        masked_signature=f"-> error.type: Str({MASK})",
        note="An allowed key keeps its shape; a recognized secret shape in its "
        "value is replaced wholesale rather than partially.",
    ),
    # --- Carriers the content scrub closes. ---
    Carrier(
        "span status message",
        "CARRIERMARKERSPANSTATUSMESSAGE",
        MASKED,
        CONTENT_SCRUB,
        masked_signature=f"Status message : {SCRUB}",
    ),
    Carrier(
        "span event name",
        "CARRIERMARKERSPANEVENTNAME",
        MASKED,
        CONTENT_SCRUB,
        masked_signature=f"-> Name: {SCRUB}",
    ),
    Carrier(
        "span trace state",
        "CARRIERMARKERSPANTRACESTATE",
        GOVERNED,
        CONTENT_SCRUB,
        note="Cleared rather than replaced, because an empty trace state is "
        "valid and a redaction token is not.",
    ),
    Carrier(
        "log body, scalar",
        "CARRIERMARKERLOGBODYSCALAR",
        MASKED,
        CONTENT_SCRUB,
        masked_signature=f"Body: Str({SCRUB})",
    ),
    Carrier(
        "log body, array",
        "CARRIERMARKERLOGBODYARRAY",
        MASKED,
        CONTENT_SCRUB,
        masked_signature=f"Body: Str({SCRUB})",
    ),
    Carrier(
        "log body, bytes",
        BYTES_MARKER,
        MASKED,
        CONTENT_SCRUB,
        masked_signature=f"Body: Str({SCRUB})",
    ),
    Carrier(
        "scalar log body matching blocked_values",
        "CARRIERMARKERMASKLOGBODY",
        MASKED,
        CONTENT_SCRUB,
        masked_signature=f"Body: Str({SCRUB})",
        note="blocked_values masks this to **** and the content scrub then "
        "replaces the whole body, so the scrub token is what reaches the "
        "exporter. Both controls apply; the later one is what is observed.",
    ),
    Carrier(
        "log severity text",
        "CARRIERMARKERLOGSEVERITYTEXT",
        MASKED,
        CONTENT_SCRUB,
        masked_signature=f"SeverityText: {SCRUB}",
        note="Scrubbed because it is a free-form emitter string with no "
        "shipped consumer. The structured severity number is unaffected.",
    ),
    Carrier(
        "log record event name",
        "CARRIERMARKERLOGEVENTNAME",
        MASKED,
        CONTENT_SCRUB,
        masked_signature=f"EventName: {SCRUB}",
    ),
    # --- Carriers a shipped consumer requires. Residual exposure, recorded. ---
    Carrier(
        "span name",
        "CARRIERMARKERSPANNAME",
        PASSED_THROUGH,
        NO_MECHANISM,
        note="Deliberately preserved. Three dashboard TraceQL queries match on "
        "span name and baseline.py reads Tempo rootTraceName. This is the "
        "carrier most likely to hold prompt text, and it is a recorded gap "
        "rather than a scrub, because scrubbing it breaks shipped panels.",
    ),
    Carrier(
        "metric name",
        "CARRIERMARKERMETRICNAME",
        PASSED_THROUGH,
        NO_MECHANISM,
        note="Preserved: every Prometheus query in the shipped dashboard selects by metric name.",
    ),
    Carrier("metric description", "CARRIERMARKERMETRICDESCRIPTION", PASSED_THROUGH, NO_MECHANISM),
    Carrier("metric unit", "CARRIERMARKERMETRICUNIT", PASSED_THROUGH, NO_MECHANISM),
    # --- Library and schema identity. Normally not emitter content, and
    # unfiltered either way: the receiver is unauthenticated and no processor
    # reaches these fields, so what they carry is an expectation about a
    # well-behaved emitter rather than a control. Recorded as G-INF-11.
    Carrier(
        "instrumentation scope name",
        "CARRIERMARKERSCOPENAME",
        PASSED_THROUGH,
        NO_MECHANISM,
        note="Unfiltered and attacker-settable; G-INF-11.",
    ),
    Carrier(
        "instrumentation scope version", "CARRIERMARKERSCOPEVERSION", PASSED_THROUGH, NO_MECHANISM
    ),
    Carrier("resource schema URL", "CARRIERMARKERRESOURCESCHEMAURL", PASSED_THROUGH, NO_MECHANISM),
    Carrier("scope schema URL", "CARRIERMARKERSCOPESCHEMAURL", PASSED_THROUGH, NO_MECHANISM),
)


def _attr(key: str, value: str) -> dict:
    return {"key": key, "value": {"stringValue": value}}


def traces_payload() -> dict:
    """One span carrying a distinct marker in every trace-side carrier."""
    return {
        "resourceSpans": [
            {
                "resource": {
                    "attributes": [
                        _attr("service.name", "copilot-chat"),
                        _attr("probe.resource.attr", "CARRIERMARKERRESOURCEATTR"),
                        *(_attr(key, marker) for key, marker in RESTORED_DETECTION_KEYS.items()),
                    ]
                },
                "schemaUrl": "https://example.invalid/CARRIERMARKERRESOURCESCHEMAURL",
                "scopeSpans": [
                    {
                        "scope": {
                            "name": "CARRIERMARKERSCOPENAME",
                            "version": "CARRIERMARKERSCOPEVERSION",
                            "attributes": [_attr("probe.scope.attr", "CARRIERMARKERSCOPEATTR")],
                        },
                        "schemaUrl": "https://example.invalid/CARRIERMARKERSCOPESCHEMAURL",
                        "spans": [
                            {
                                "traceId": "5b8efff798038103d269b633813fc60c",
                                "spanId": "eee19b7ec3c1b174",
                                "traceState": "probe=CARRIERMARKERSPANTRACESTATE",
                                "name": "CARRIERMARKERSPANNAME",
                                "kind": 1,
                                "startTimeUnixNano": "1700000000000000000",
                                "endTimeUnixNano": "1700000001000000000",
                                "attributes": [
                                    _attr("probe.span.attr", "CARRIERMARKERSPANATTR"),
                                    # An allow-listed key whose value carries a
                                    # recognized secret shape, so masking can be
                                    # observed separately from dropping.
                                    _attr(
                                        "error.type",
                                        "password=CARRIERMARKERMASKSPANATTR",
                                    ),
                                ],
                                "status": {
                                    "code": 2,
                                    "message": "CARRIERMARKERSPANSTATUSMESSAGE",
                                },
                                "events": [
                                    {
                                        "timeUnixNano": "1700000000500000000",
                                        "name": "CARRIERMARKERSPANEVENTNAME",
                                        "attributes": [
                                            _attr(
                                                "probe.spanevent.attr",
                                                "CARRIERMARKERSPANEVENTATTR",
                                            )
                                        ],
                                    }
                                ],
                                "links": [
                                    {
                                        "traceId": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                                        "spanId": "bbbbbbbbbbbbbbbb",
                                        "traceState": "probe=CARRIERMARKERLINKTRACESTATE",
                                        "attributes": [
                                            _attr("probe.link.attr", "CARRIERMARKERLINKATTR")
                                        ],
                                    }
                                ],
                            }
                        ],
                    }
                ],
            }
        ]
    }


def logs_payload() -> dict:
    """Log records covering every body shape and the non-body log fields."""
    return {
        "resourceLogs": [
            {
                "resource": {"attributes": [_attr("service.name", "copilot-chat")]},
                "scopeLogs": [
                    {
                        "scope": {"name": "probe"},
                        "logRecords": [
                            {
                                "timeUnixNano": "1700000000000000000",
                                "severityNumber": 9,
                                "severityText": "CARRIERMARKERLOGSEVERITYTEXT",
                                "eventName": "CARRIERMARKERLOGEVENTNAME",
                                "body": {"stringValue": "CARRIERMARKERLOGBODYSCALAR"},
                                "attributes": [_attr("probe.log.attr", "CARRIERMARKERLOGATTR")],
                            },
                            {
                                "timeUnixNano": "1700000000000000000",
                                "body": {
                                    "kvlistValue": {
                                        "values": [
                                            _attr(
                                                "probe.body.key",
                                                "CARRIERMARKERLOGBODYMAP",
                                            )
                                        ]
                                    }
                                },
                            },
                            {
                                "timeUnixNano": "1700000000000000000",
                                "body": {
                                    "arrayValue": {
                                        "values": [{"stringValue": "CARRIERMARKERLOGBODYARRAY"}]
                                    }
                                },
                            },
                            {
                                "timeUnixNano": "1700000000000000000",
                                "body": {"bytesValue": BYTES_MARKER},
                            },
                            {
                                "timeUnixNano": "1700000000000000000",
                                "body": {"stringValue": "password=CARRIERMARKERMASKLOGBODY"},
                            },
                        ],
                    }
                ],
            }
        ]
    }


def metrics_payload() -> dict:
    """One datapoint carrying markers in metric metadata, attributes, exemplars."""
    return {
        "resourceMetrics": [
            {
                "resource": {"attributes": [_attr("service.name", "copilot-chat")]},
                "scopeMetrics": [
                    {
                        "scope": {"name": "probe"},
                        "metrics": [
                            {
                                "name": "CARRIERMARKERMETRICNAME",
                                "description": "CARRIERMARKERMETRICDESCRIPTION",
                                "unit": "CARRIERMARKERMETRICUNIT",
                                "sum": {
                                    "aggregationTemporality": 2,
                                    "isMonotonic": True,
                                    "dataPoints": [
                                        {
                                            "startTimeUnixNano": "1700000000000000000",
                                            "timeUnixNano": "1700000001000000000",
                                            "asInt": "1",
                                            "attributes": [
                                                _attr(
                                                    "probe.datapoint.attr",
                                                    "CARRIERMARKERDATAPOINTATTR",
                                                )
                                            ],
                                            "exemplars": [
                                                {
                                                    "timeUnixNano": "1700000001000000000",
                                                    "asInt": "1",
                                                    "traceId": ("5b8efff798038103d269b633813fc60c"),
                                                    "spanId": "eee19b7ec3c1b174",
                                                    "filteredAttributes": [
                                                        _attr(
                                                            "probe.exemplar.attr",
                                                            "CARRIERMARKEREXEMPLARATTR",
                                                        )
                                                    ],
                                                }
                                            ],
                                        }
                                    ],
                                },
                            }
                        ],
                    }
                ],
            }
        ]
    }


def pinned_collector_image() -> str:
    """The digest-pinned Collector image the shipped stack runs."""
    compose = yaml.safe_load(COMPOSE_PATH.read_text(encoding="utf-8"))
    return compose["services"][COLLECTOR_SERVICE]["image"]


def shipped_collector_config() -> dict:
    return yaml.safe_load(COLLECTOR_PATH.read_text(encoding="utf-8"))


def policy_document(policy_source: str) -> dict:
    """The shipped document that owns the content-minimization processors."""
    path = COLLECTOR_PATH if policy_source == LOCAL_POLICY else FLEET_COLLECTOR_PATH
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def derive_probe_config(
    *, remove_content_processors: bool, policy_source: str = LOCAL_POLICY
) -> dict:
    """Derive a probe configuration from the shipped file.

    The only permitted substitution for an ordinary run is exporter wiring, so
    the Collector emits inspectable records instead of shipping them to a store
    this harness does not start. Receivers, processors, and processor ordering
    are preserved. The negative control is additionally permitted to remove
    every content-minimization processor, and makes no other policy change.

    A fleet run substitutes the two content-minimization processor definitions
    from the fleet document and nothing else. Transport stays local because the
    fleet receiver requires TLS material and a bearer credential this harness
    does not hold, and because the fleet exporter targets a store it does not
    start. What is under test is the policy, and the policy is what is swapped.
    """
    config = copy.deepcopy(shipped_collector_config())

    if policy_source != LOCAL_POLICY:
        source = policy_document(policy_source)
        for name in CONTENT_PROCESSORS:
            config["processors"][name] = copy.deepcopy(source["processors"][name])

    config["exporters"] = {"debug": {"verbosity": "detailed"}}
    # A ten second batch window would dominate the probe's runtime without
    # changing what the policy does to a record.
    config["processors"]["batch"]["timeout"] = "1s"

    if remove_content_processors:
        for name in CONTENT_PROCESSORS:
            config["processors"].pop(name, None)

    for pipeline in config["service"]["pipelines"].values():
        pipeline["exporters"] = ["debug"]
        if remove_content_processors:
            pipeline["processors"] = [
                name for name in pipeline["processors"] if name not in CONTENT_PROCESSORS
            ]

    return config


class ContainerRuntime:
    """A Docker CLI this platform can actually reach."""

    def __init__(self, argv: list[str], label: str) -> None:
        self._argv = argv
        self.label = label

    def docker(self, *args: str, timeout: float = 300.0) -> subprocess.CompletedProcess[str]:
        return subprocess.run(  # noqa: S603 - fixed argv, no shell
            [*self._argv, *args],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )

    def mount_source(self, path: pathlib.Path) -> str:
        """Render a host path in the form this Docker CLI can bind-mount."""
        return path.as_posix()

    def openssl(
        self, *args: str, cwd: pathlib.Path, timeout: float = 120.0
    ) -> subprocess.CompletedProcess[str]:
        """Run OpenSSL where this runtime's files live, using relative names."""
        return subprocess.run(  # noqa: S603 - fixed argv, no shell
            ["openssl", *args],
            cwd=str(cwd),
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )

    def has_openssl(self) -> bool:
        return shutil.which("openssl") is not None


class _WslDockerRuntime(ContainerRuntime):
    """Windows hosts where Docker is reachable only inside WSL."""

    def mount_source(self, path: pathlib.Path) -> str:
        translated = subprocess.run(  # noqa: S603 - fixed argv, no shell
            ["wsl.exe", "-e", "wslpath", "-a", path.as_posix()],
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        if translated.returncode != 0:
            raise RuntimeError(f"wslpath failed: {translated.stderr.strip()}")
        return translated.stdout.strip()

    def openssl(
        self, *args: str, cwd: pathlib.Path, timeout: float = 120.0
    ) -> subprocess.CompletedProcess[str]:
        # The certificate has to be readable by the same daemon that mounts it,
        # so it is produced by the OpenSSL that lives beside that daemon.
        return subprocess.run(  # noqa: S603 - fixed argv, no shell
            [
                "wsl.exe",
                "-e",
                "sh",
                "-c",
                'cd "$1" && shift && exec openssl "$@"',
                "sh",
                self.mount_source(cwd),
                *args,
            ],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )

    def has_openssl(self) -> bool:
        probe = subprocess.run(  # noqa: S603 - fixed argv, no shell
            ["wsl.exe", "-e", "openssl", "version"],
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        return probe.returncode == 0


def detect_runtime() -> ContainerRuntime | None:
    """Find a reachable Docker daemon without assuming a platform.

    The platform CLI is tried first so the harness executes on the Linux CI
    lane. WSL is a Windows-only fallback for hosts where the daemon lives
    inside a distribution and no Windows CLI reaches it.
    """
    candidates: list[ContainerRuntime] = []
    if shutil.which("docker"):
        candidates.append(ContainerRuntime(["docker"], "platform docker CLI"))
    if platform.system() == "Windows" and shutil.which("wsl.exe"):
        candidates.append(_WslDockerRuntime(["wsl.exe", "-e", "docker"], "docker inside WSL"))

    for candidate in candidates:
        try:
            probe = candidate.docker("version", "--format", "{{.Server.Version}}", timeout=60)
        except (OSError, subprocess.SubprocessError):
            continue
        if probe.returncode == 0 and probe.stdout.strip():
            return candidate
    return None


def strict_runtime_required(env: Mapping[str, str] | None = None) -> bool:
    """Whether a missing container runtime must fail this module rather than skip it.

    Only `STRICT_RUNTIME_ENV` decides. The lane that selects these tests also
    provisions Docker and pre-pulls the pinned image, so it is the only caller
    positioned to promise that a green result means the probes ran. Inferring
    strictness from an ambient signal would impose that promise on runners that
    never selected the module.
    """
    source = os.environ if env is None else env
    chosen = source.get(STRICT_RUNTIME_ENV, "")
    return chosen.strip().lower() not in _FALSE_VALUES


NO_RUNTIME_REASON = (
    "container runtime is unavailable: no reachable Docker daemon through the "
    "platform CLI or, on Windows, through WSL. The carrier map was not "
    "verified by this run."
)


def resolve_runtime() -> ContainerRuntime:
    """Return a reachable runtime, or stop this module the way strictness requires."""
    found = detect_runtime()
    if found is None:
        if strict_runtime_required():
            pytest.fail(
                f"{NO_RUNTIME_REASON} Strict mode is active, so this is a failure and "
                f"not a skip: the runtime-backed claims in SECURITY.md cite this "
                f"module, and a silent skip would leave them citing a run that never "
                f"happened. Set {STRICT_RUNTIME_ENV}=0 to allow the skip.",
                pytrace=False,
            )
        pytest.skip(NO_RUNTIME_REASON)
    return found


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


@dataclass
class ProbeResult:
    """What the Collector emitted for one configuration."""

    output: str
    config: dict
    posted: list[str] = field(default_factory=list)


def _wait_for_health(port: int, *, timeout: float) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(  # noqa: S310 - fixed loopback URL
                f"http://127.0.0.1:{port}/", timeout=5
            ) as response:
                if response.status == 200:
                    return True
        except (urllib.error.URLError, TimeoutError, OSError):
            time.sleep(0.5)
    return False


def _post(port: int, signal: str, payload: dict) -> None:
    request = urllib.request.Request(  # noqa: S310 - fixed loopback URL
        f"http://127.0.0.1:{port}/v1/{signal}",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=30) as response:  # noqa: S310
        if response.status != 200:
            raise RuntimeError(f"{signal} export returned HTTP {response.status}")


def run_probe(
    runtime: ContainerRuntime,
    *,
    remove_content_processors: bool,
    policy_source: str = LOCAL_POLICY,
) -> ProbeResult:
    """Start a disposable Collector, export every marker, capture the output."""
    config = derive_probe_config(
        remove_content_processors=remove_content_processors, policy_source=policy_source
    )
    http_port = _free_port()
    health_port = _free_port()
    variant = "control" if remove_content_processors else policy_source
    container = f"copilot-otel-carrier-probe-{variant}-{http_port}"

    with tempfile.TemporaryDirectory(prefix="copilot-otel-probe-") as workdir:
        config_path = pathlib.Path(workdir) / "config.yaml"
        config_path.write_text(yaml.safe_dump(config, sort_keys=False), encoding="utf-8")

        started = runtime.docker(
            "run",
            "-d",
            "--name",
            container,
            "-p",
            f"127.0.0.1:{http_port}:4318",
            "-p",
            f"127.0.0.1:{health_port}:13133",
            "-v",
            f"{runtime.mount_source(config_path)}:/etc/otelcol-contrib/config.yaml:ro",
            pinned_collector_image(),
            "--config=/etc/otelcol-contrib/config.yaml",
        )
        if started.returncode != 0:
            raise RuntimeError(f"probe container failed to start: {started.stderr.strip()}")

        try:
            if not _wait_for_health(health_port, timeout=60):
                logs = runtime.docker("logs", container)
                raise RuntimeError(
                    f"probe Collector never became healthy; output:\n{logs.stdout}\n{logs.stderr}"
                )

            posted = []
            for signal, payload in (
                ("traces", traces_payload()),
                ("logs", logs_payload()),
                ("metrics", metrics_payload()),
            ):
                _post(http_port, signal, payload)
                posted.append(signal)

            output = _await_all_signals(runtime, container, timeout=30)
            return ProbeResult(output=output, config=config, posted=posted)
        finally:
            runtime.docker("rm", "-f", container, timeout=120)


def _await_all_signals(runtime: ContainerRuntime, container: str, *, timeout: float) -> str:
    """Wait until the exporter has rendered all three signals, then return them."""
    expected = (
        '"otelcol.signal": "traces"',
        '"otelcol.signal": "logs"',
        '"otelcol.signal": "metrics"',
    )
    deadline = time.monotonic() + timeout
    output = ""
    while time.monotonic() < deadline:
        logs = runtime.docker("logs", container, timeout=60)
        output = logs.stdout + logs.stderr
        if all(marker in output for marker in expected):
            return output
        time.sleep(1)
    missing = [marker for marker in expected if marker not in output]
    raise RuntimeError(f"exporter never rendered {missing}; captured output:\n{output}")


def classify(carrier: Carrier, policy_output: str, control_output: str) -> str:
    """Classify one carrier from the paired runs.

    The control decides observability first. Only a marker the instrument can
    render is eligible to be called governed; anything else is `unobservable`
    and is carried as a gap rather than counted as a control.
    """
    if carrier.marker not in control_output:
        return UNOBSERVABLE
    if carrier.marker in policy_output:
        return PASSED_THROUGH
    if carrier.masked_signature and carrier.masked_signature in policy_output:
        return MASKED
    return GOVERNED


@pytest.fixture(scope="module")
def runtime() -> ContainerRuntime:
    return resolve_runtime()


@pytest.fixture(scope="module", params=POLICY_SOURCES)
def policy_output(request: pytest.FixtureRequest, runtime: ContainerRuntime) -> str:
    return run_probe(runtime, remove_content_processors=False, policy_source=request.param).output


@pytest.fixture(scope="module")
def control_output(runtime: ContainerRuntime) -> str:
    return run_probe(runtime, remove_content_processors=True).output


class TestMarkerInventory:
    """The markers must be distinguishable before any classification means anything."""

    def test_given_the_carrier_map_when_markers_are_collected_then_each_is_unique(self) -> None:
        # Act
        markers = [carrier.marker for carrier in CARRIERS]

        # Assert
        assert len(markers) == len(set(markers))

    def test_given_the_carrier_map_when_markers_are_compared_pairwise_then_none_is_a_substring(
        self,
    ) -> None:
        # Act
        overlapping = [
            (one.name, other.name)
            for one in CARRIERS
            for other in CARRIERS
            if one is not other and one.marker in other.marker
        ]

        # Assert
        assert overlapping == []

    def test_given_the_carrier_map_when_expectations_are_checked_then_each_class_is_known(
        self,
    ) -> None:
        # Arrange
        allowed = {GOVERNED, MASKED, PASSED_THROUGH}

        # Act
        unknown = [c.name for c in CARRIERS if c.expected not in allowed]

        # Assert
        assert unknown == [], (
            "An unobservable or unclassified carrier is a gap, not a baseline. "
            "Record it in SECURITY.md rather than encoding it as an expectation."
        )

    def test_given_a_masked_carrier_when_its_entry_is_read_then_a_masked_signature_is_declared(
        self,
    ) -> None:
        # Act
        undeclared = [c.name for c in CARRIERS if c.expected == MASKED and not c.masked_signature]

        # Assert
        assert undeclared == []

    def test_given_a_passed_through_carrier_when_its_entry_is_read_then_no_mechanism_is_claimed(
        self,
    ) -> None:
        """A carrier cannot claim a control and pass through at the same time."""
        # Act
        contradictory = [
            c.name for c in CARRIERS if c.expected == PASSED_THROUGH and c.mechanism != NO_MECHANISM
        ]

        # Assert
        assert contradictory == []

    def test_given_a_governed_or_masked_carrier_when_its_entry_is_read_then_a_mechanism_is_named(
        self,
    ) -> None:
        # Act
        unattributed = [
            c.name
            for c in CARRIERS
            if c.expected in {GOVERNED, MASKED} and c.mechanism == NO_MECHANISM
        ]

        # Assert
        assert unattributed == []


class TestProbeConfigDerivation:
    """The configuration under test must be the shipped one, minus stated changes."""

    def test_given_the_shipped_config_when_a_probe_config_is_derived_then_processor_order_is_kept(
        self,
    ) -> None:
        # Arrange
        shipped = shipped_collector_config()

        # Act
        derived = derive_probe_config(remove_content_processors=False)

        # Assert
        for name, pipeline in derived["service"]["pipelines"].items():
            assert pipeline["processors"] == shipped["service"]["pipelines"][name]["processors"]

    def test_given_the_shipped_config_when_a_probe_config_is_derived_then_redaction_policy_is_kept(
        self,
    ) -> None:
        # Arrange
        shipped = shipped_collector_config()

        # Act
        derived = derive_probe_config(remove_content_processors=False)

        # Assert
        assert derived["processors"]["redaction"] == shipped["processors"]["redaction"]

    def test_given_a_control_config_when_it_is_derived_then_only_content_processors_are_removed(
        self,
    ) -> None:
        # Act
        policy = derive_probe_config(remove_content_processors=False)
        control = derive_probe_config(remove_content_processors=True)

        # Assert
        assert set(policy["processors"]) - set(control["processors"]) == set(CONTENT_PROCESSORS)
        for name, pipeline in control["service"]["pipelines"].items():
            expected = [
                step
                for step in policy["service"]["pipelines"][name]["processors"]
                if step not in CONTENT_PROCESSORS
            ]
            assert pipeline["processors"] == expected

    def test_given_the_compose_file_when_the_probe_image_is_resolved_then_it_is_digest_pinned(
        self,
    ) -> None:
        # Act & Assert
        assert "@sha256:" in pinned_collector_image()

    def test_given_fleet_policy_when_a_probe_config_is_derived_then_fleet_content_processors_apply(
        self,
    ) -> None:
        # Arrange
        fleet = policy_document(FLEET_POLICY)

        # Act
        derived = derive_probe_config(remove_content_processors=False, policy_source=FLEET_POLICY)

        # Assert
        for name in CONTENT_PROCESSORS:
            assert derived["processors"][name] == fleet["processors"][name]

    def test_given_fleet_policy_when_a_probe_config_is_derived_then_transport_blocks_are_unchanged(
        self,
    ) -> None:
        """Swapping transport as well would test the fleet's network, not its policy."""
        # Act
        local = derive_probe_config(remove_content_processors=False)
        fleet = derive_probe_config(remove_content_processors=False, policy_source=FLEET_POLICY)

        # Assert
        assert local["receivers"] == fleet["receivers"]
        assert local["exporters"] == fleet["exporters"]
        assert local["service"] == fleet["service"]
        differing = {
            name
            for name in local["processors"]
            if local["processors"][name] != fleet["processors"][name]
        }
        assert differing <= set(CONTENT_PROCESSORS)


class TestStrictRuntimeMode:
    """A run that produces no evidence must not be able to pass quietly.

    This module's output is what `SECURITY.md` cites. If the lane ever loses a
    usable container runtime, a skip would keep the suite green while those
    claims cite a run that never happened, which is the defect this suite
    exists to prevent, one level up. The rule that decides between skipping and
    failing is therefore asserted rather than trusted, including its refusal to
    infer strictness from an ambient signal.
    """

    @pytest.mark.parametrize(
        ("env", "expected"),
        [
            ({}, False),
            ({"CI": "true"}, False),
            ({"CI": "1"}, False),
            ({STRICT_RUNTIME_ENV: "1"}, True),
            ({STRICT_RUNTIME_ENV: "true", "CI": "false"}, True),
            ({STRICT_RUNTIME_ENV: "0", "CI": "true"}, False),
            ({STRICT_RUNTIME_ENV: "off", "CI": "true"}, False),
            ({STRICT_RUNTIME_ENV: ""}, False),
        ],
    )
    def test_given_an_environment_mapping_when_strictness_is_resolved_then_the_flag_decides(
        self,
        env: dict[str, str],
        expected: bool,
    ) -> None:
        # Act & Assert
        assert strict_runtime_required(env) is expected

    def test_given_no_container_runtime_when_strictness_is_on_then_resolution_fails_loudly(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        monkeypatch.setitem(globals(), "detect_runtime", lambda: None)
        monkeypatch.setenv(STRICT_RUNTIME_ENV, "1")

        # Act
        with pytest.raises(pytest.fail.Exception) as raised:
            resolve_runtime()

        # Assert
        assert STRICT_RUNTIME_ENV in str(raised.value)

    def test_given_no_container_runtime_when_strictness_is_off_then_resolution_skips(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        monkeypatch.setitem(globals(), "detect_runtime", lambda: None)
        monkeypatch.setenv(STRICT_RUNTIME_ENV, "0")

        # Act & Assert
        with pytest.raises(pytest.skip.Exception):
            resolve_runtime()

    def test_given_a_reachable_runtime_when_strictness_is_on_then_that_runtime_is_returned(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Arrange
        stub = ContainerRuntime(["docker"], "stub runtime")
        monkeypatch.setitem(globals(), "detect_runtime", lambda: stub)
        monkeypatch.setenv(STRICT_RUNTIME_ENV, "1")

        # Act & Assert
        assert resolve_runtime() is stub


class TestProcessorChainPosition:
    """A content processor must sit after memory_limiter and before batch.

    Ahead of `memory_limiter` it would do work the limiter exists to shed;
    after `batch` it would run on assembled batches instead of records.
    """

    @pytest.mark.parametrize("processor", CONTENT_PROCESSORS)
    def test_given_a_content_processor_when_the_chain_is_read_then_it_follows_the_limiter(
        self,
        processor: str,
    ) -> None:
        # Act
        pipelines = shipped_collector_config()["service"]["pipelines"]

        # Assert
        for name, pipeline in pipelines.items():
            chain = pipeline["processors"]
            assert processor in chain, f"{name} does not apply {processor}"
            assert chain.index("memory_limiter") < chain.index(processor) < chain.index("batch"), (
                f"{name} applies {processor} outside the limiter-to-batch window"
            )


class TestNegativeControl:
    """Validate the instrument before trusting anything it reports."""

    @pytest.mark.parametrize("carrier", CARRIERS, ids=lambda c: c.name)
    def test_given_the_control_run_when_a_carrier_is_probed_then_its_marker_is_rendered(
        self, carrier: Carrier, control_output: str
    ) -> None:
        # Assert
        assert carrier.marker in control_output, (
            f"{carrier.name} is not rendered even with the content processors "
            f"removed, so its absence under policy proves nothing. Classify it "
            f"{UNOBSERVABLE} and record it as a gap rather than as a control."
        )


class TestCarrierMap:
    """The recorded map is the regression boundary."""

    @pytest.mark.parametrize("carrier", CARRIERS, ids=lambda c: c.name)
    def test_given_paired_policy_and_control_runs_when_a_carrier_is_classified_then_the_map_holds(
        self, carrier: Carrier, policy_output: str, control_output: str
    ) -> None:
        # Act
        observed = classify(carrier, policy_output, control_output)

        # Assert
        assert observed == carrier.expected, (
            f"{carrier.name} is now {observed}, recorded as {carrier.expected}. "
            "Rebaselining this entry is a policy decision and needs its own "
            "evidence; do not edit the map to make this pass."
        )


class TestRestoredDetectionAttributes:
    """An allow-list entry is a claim until the Collector is observed keeping it.

    Three of these keys were dropped by the allow-list while shipped consumers
    read them, and one of them exists in two candidate spellings because the
    Prometheus label it produces cannot be reversed into an OTLP key. Asserting
    survival per key is what makes a wrong entry fail here rather than in a
    silently empty panel.
    """

    @pytest.mark.parametrize("key", sorted(RESTORED_DETECTION_KEYS))
    def test_given_a_restored_detection_key_when_the_shipped_policy_runs_then_its_marker_survives(
        self,
        key: str,
        policy_output: str,
    ) -> None:
        # Assert
        assert RESTORED_DETECTION_KEYS[key] in policy_output, (
            f"{key} is in the allow-list but was dropped by the running Collector"
        )

    @pytest.mark.parametrize("key", sorted(RESTORED_DETECTION_KEYS))
    def test_given_a_restored_detection_key_when_the_exporter_renders_it_then_its_own_key_is_used(
        self, key: str, policy_output: str
    ) -> None:
        # Assert
        assert f"-> {key}: Str({RESTORED_DETECTION_KEYS[key]})" in policy_output


class TestShippedConfigurationStartsClean:
    """One start of the configuration as shipped, with nothing substituted.

    The carrier harness replaces the exporter block so it can inspect records,
    which means it can never observe an exporter-level startup warning. This
    runs the file exactly as an operator runs it.
    """

    def test_given_the_shipped_configuration_when_the_collector_starts_then_no_deprecation_logs(
        self, runtime: ContainerRuntime
    ) -> None:
        # Arrange
        container = f"copilot-otel-alias-check-{_free_port()}"

        # Act
        started = runtime.docker(
            "run",
            "-d",
            "--name",
            container,
            "-v",
            f"{runtime.mount_source(COLLECTOR_PATH)}:/etc/otelcol-contrib/config.yaml:ro",
            pinned_collector_image(),
            "--config=/etc/otelcol-contrib/config.yaml",
        )
        if started.returncode != 0:
            raise RuntimeError(f"shipped configuration failed to start: {started.stderr.strip()}")
        try:
            # The exporter is built during startup, so the warning appears in
            # the first seconds. Waiting for the LGTM connection to fail is not
            # required and would only add flake.
            deadline = time.monotonic() + 30
            output = ""
            while time.monotonic() < deadline:
                logs = runtime.docker("logs", container, timeout=60)
                output = logs.stdout + logs.stderr
                if "Everything is ready" in output:
                    break
                time.sleep(1)

            # Assert
            assert "Everything is ready" in output, f"Collector never finished starting:\n{output}"
            assert "deprecated" not in output.lower(), (
                f"the shipped configuration still triggers a deprecation warning:\n{output}"
            )
        finally:
            runtime.docker("rm", "-f", container, timeout=120)


# --- Agent-host relay ------------------------------------------------------
#
# The relay is the only carrier for organization-managed agent-host telemetry,
# and everything that makes it safe is transport: it must reach the fleet
# receiver over TLS it verified against the operator's bundle, carrying the
# fleet credential, and it must refuse to forward when any of that is wrong.
# None of that is observable in a configuration file, so the shipped relay is
# run against a disposable receiver that holds the other half of the handshake.

RELAY_COLLECTOR_PATH = (
    SKILL_ROOT / "examples" / "azure" / "agent-host-relay" / ("otel-collector-config.yaml")
)
RELAY_SAN_HOST = "fleet-receiver"
RELAY_WRONG_HOST = "other-receiver-name"
RELAY_TOKEN = "relay-runtime-fleet-token"
RELAY_CA_MOUNT = "/run/copilot-otel/fleet-ca.pem"
RELAY_MARKER_ATTRIBUTE = "session.id"

NO_OPENSSL_REASON = (
    "OpenSSL is unavailable beside the container runtime, so no ephemeral CA "
    "and server certificate could be issued. The relay's TLS and credential "
    "behaviour was not verified by this run."
)


@dataclass(frozen=True)
class RelayCase:
    """One end-to-end relay attempt and whether forwarding may succeed."""

    name: str
    token: str
    ca_file: str
    endpoint_host: str
    forwards: bool


RELAY_CASES = (
    RelayCase("trusted", RELAY_TOKEN, "ca.pem", RELAY_SAN_HOST, forwards=True),
    RelayCase("wrong-bearer", "not-the-fleet-token", "ca.pem", RELAY_SAN_HOST, forwards=False),
    RelayCase("untrusted-ca", RELAY_TOKEN, "other-ca.pem", RELAY_SAN_HOST, forwards=False),
    RelayCase("hostname-mismatch", RELAY_TOKEN, "ca.pem", RELAY_WRONG_HOST, forwards=False),
)


def resolve_openssl(runtime: ContainerRuntime) -> None:
    """Stop this module the way strictness requires when OpenSSL is missing."""
    if runtime.has_openssl():
        return
    if strict_runtime_required():
        pytest.fail(
            f"{NO_OPENSSL_REASON} Strict mode is active, so this is a failure and "
            f"not a skip. Set {STRICT_RUNTIME_ENV}=0 to allow the skip.",
            pytrace=False,
        )
    pytest.skip(NO_OPENSSL_REASON)


def _issue_relay_material(runtime: ContainerRuntime, workdir: pathlib.Path) -> None:
    """Issue a throwaway CA, a SAN-matched server certificate, and a rival CA.

    The rival CA is what makes the untrusted-certificate case a real rejection
    rather than an absence: the receiver still presents a valid certificate,
    signed by an authority the relay was not given.
    """
    # Only RELAY_SAN_HOST is named, so the mismatched-hostname case rests on
    # the certificate rather than on the receiver refusing the connection.
    (workdir / "san.cnf").write_text(f"subjectAltName=DNS:{RELAY_SAN_HOST}\n", encoding="utf-8")
    commands = [
        # The authority the relay is told to trust.
        (
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-keyout",
            "ca.key",
            "-out",
            "ca.pem",
            "-days",
            "1",
            "-subj",
            "/CN=copilot-otel-relay-test-ca",
            "-addext",
            "basicConstraints=critical,CA:TRUE",
        ),
        # An authority the relay is never told about.
        (
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-keyout",
            "other-ca.key",
            "-out",
            "other-ca.pem",
            "-days",
            "1",
            "-subj",
            "/CN=copilot-otel-rival-ca",
            "-addext",
            "basicConstraints=critical,CA:TRUE",
        ),
        (
            "req",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-keyout",
            "server.key",
            "-out",
            "server.csr",
            "-subj",
            f"/CN={RELAY_SAN_HOST}",
        ),
        (
            "x509",
            "-req",
            "-in",
            "server.csr",
            "-CA",
            "ca.pem",
            "-CAkey",
            "ca.key",
            "-CAcreateserial",
            "-out",
            "server.crt",
            "-days",
            "1",
            "-extfile",
            "san.cnf",
        ),
    ]
    for command in commands:
        result = runtime.openssl(*command, cwd=workdir)
        if result.returncode != 0:
            raise RuntimeError(f"openssl {command[0]} failed: {result.stderr.strip()}")

    # OpenSSL writes keys 0600 for the creating user; the Collector image runs
    # as a different UID and the bind mount carries host mode through.
    for key in workdir.glob("*.key"):
        key.chmod(0o644)


def _fleet_receiver_config() -> dict:
    """A disposable stand-in for the fleet receiver: TLS, bearer auth, and a log."""
    return {
        "receivers": {
            "otlp": {
                "protocols": {
                    "http": {
                        "endpoint": "0.0.0.0:4318",
                        "auth": {"authenticator": "bearertokenauth"},
                        "tls": {
                            "cert_file": "/etc/otel/server.crt",
                            "key_file": "/etc/otel/server.key",
                        },
                    }
                }
            }
        },
        "exporters": {"debug": {"verbosity": "detailed"}},
        "extensions": {
            "health_check": {"endpoint": "0.0.0.0:13133"},
            "bearertokenauth": {"scheme": "Bearer", "token": RELAY_TOKEN},
        },
        "service": {
            "extensions": ["health_check", "bearertokenauth"],
            "pipelines": {"traces": {"receivers": ["otlp"], "exporters": ["debug"]}},
        },
    }


def _agent_host_payload(marker: str) -> dict:
    """A trace only the agent host would produce, carrying a unique marker."""
    return {
        "resourceSpans": [
            {
                "resource": {
                    "attributes": [
                        {"key": "service.name", "value": {"stringValue": "copilot-agent-host"}}
                    ]
                },
                "scopeSpans": [
                    {
                        "scope": {"name": "copilot-otel-relay-test"},
                        "spans": [
                            {
                                "traceId": "d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5",
                                "spanId": "a1b2c3d4e5f60718",
                                "name": "invoke_agent",
                                "kind": 1,
                                "startTimeUnixNano": "1700000000000000000",
                                "endTimeUnixNano": "1700000000100000000",
                                "attributes": [
                                    {
                                        "key": RELAY_MARKER_ATTRIBUTE,
                                        "value": {"stringValue": marker},
                                    }
                                ],
                            }
                        ],
                    }
                ],
            }
        ]
    }


def _container_logs(runtime: ContainerRuntime, container: str) -> str:
    logs = runtime.docker("logs", container, timeout=60)
    return logs.stdout + logs.stderr


def run_relay_case(runtime: ContainerRuntime, case: RelayCase) -> tuple[str, str]:
    """Run the shipped relay against a disposable fleet receiver.

    Returns the receiver's output and the relay's own output. The relay
    configuration is used exactly as shipped, including its ten second batch
    window, so nothing about the transport under test is a test-only variant.
    """
    marker = f"RELAYMARKER{case.name.upper().replace('-', '')}{_free_port()}"
    network = f"copilot-otel-relay-net-{_free_port()}"
    receiver_container = f"copilot-otel-relay-receiver-{_free_port()}"
    relay_container = f"copilot-otel-relay-{_free_port()}"
    relay_http_port = _free_port()
    receiver_health_port = _free_port()
    relay_health_port = _free_port()

    with tempfile.TemporaryDirectory(prefix="copilot-otel-relay-") as raw_workdir:
        workdir = pathlib.Path(raw_workdir)
        _issue_relay_material(runtime, workdir)
        receiver_config = workdir / "receiver.yaml"
        receiver_config.write_text(
            yaml.safe_dump(_fleet_receiver_config(), sort_keys=False), encoding="utf-8"
        )

        created = runtime.docker("network", "create", network)
        if created.returncode != 0:
            raise RuntimeError(f"relay test network failed: {created.stderr.strip()}")
        try:
            started = runtime.docker(
                "run",
                "-d",
                "--name",
                receiver_container,
                "--network",
                network,
                "--network-alias",
                RELAY_SAN_HOST,
                "--network-alias",
                RELAY_WRONG_HOST,
                "-p",
                f"127.0.0.1:{receiver_health_port}:13133",
                "-v",
                f"{runtime.mount_source(receiver_config)}:/etc/otelcol-contrib/config.yaml:ro",
                "-v",
                f"{runtime.mount_source(workdir / 'server.crt')}:/etc/otel/server.crt:ro",
                "-v",
                f"{runtime.mount_source(workdir / 'server.key')}:/etc/otel/server.key:ro",
                pinned_collector_image(),
                "--config=/etc/otelcol-contrib/config.yaml",
            )
            if started.returncode != 0:
                raise RuntimeError(f"fleet receiver failed to start: {started.stderr.strip()}")

            started = runtime.docker(
                "run",
                "-d",
                "--name",
                relay_container,
                "--network",
                network,
                "-e",
                f"COPILOT_OTEL_FLEET_ENDPOINT=https://{case.endpoint_host}:4318",
                "-e",
                f"COPILOT_OTEL_INGEST_TOKEN={case.token}",
                "-p",
                f"127.0.0.1:{relay_http_port}:4318",
                "-p",
                f"127.0.0.1:{relay_health_port}:13133",
                "-v",
                f"{runtime.mount_source(RELAY_COLLECTOR_PATH)}:/etc/otelcol-contrib/config.yaml:ro",
                "-v",
                f"{runtime.mount_source(workdir / case.ca_file)}:{RELAY_CA_MOUNT}:ro",
                pinned_collector_image(),
                "--config=/etc/otelcol-contrib/config.yaml",
            )
            if started.returncode != 0:
                raise RuntimeError(f"relay failed to start: {started.stderr.strip()}")

            for name, port in (
                (receiver_container, receiver_health_port),
                (relay_container, relay_health_port),
            ):
                if not _wait_for_health(port, timeout=60):
                    raise RuntimeError(
                        f"{name} never became healthy; output:\n{_container_logs(runtime, name)}"
                    )

            _post(relay_http_port, "traces", _agent_host_payload(marker))

            # The shipped relay batches for ten seconds, so no verdict is
            # available until that window has passed at least once.
            deadline = time.monotonic() + 45
            receiver_output = ""
            while time.monotonic() < deadline:
                receiver_output = _container_logs(runtime, receiver_container)
                if marker in receiver_output:
                    break
                time.sleep(1)
            relay_output = _container_logs(runtime, relay_container)
            return receiver_output.replace(marker, "AGENTHOSTMARKER"), relay_output
        finally:
            for name in (relay_container, receiver_container):
                runtime.docker("rm", "-f", name, timeout=120)
            runtime.docker("network", "rm", network, timeout=120)


@pytest.fixture(scope="module")
def relay_results(runtime: ContainerRuntime) -> dict[str, tuple[str, str]]:
    """Every relay case, run once, because each one starts two containers."""
    resolve_openssl(runtime)
    return {case.name: run_relay_case(runtime, case) for case in RELAY_CASES}


class TestAgentHostRelay:
    """The shipped relay forwards only over verified TLS with the fleet credential.

    A static check can confirm the relay declares a CA file and an
    authenticator. It cannot confirm that the Collector refuses a receiver
    signed by another authority, or one whose certificate does not name the
    host the relay dialled. Those are the failures that would otherwise be
    found by a fleet already sending telemetry somewhere it should not.
    """

    def test_given_a_trusted_receiver_and_credential_when_the_relay_forwards_then_the_span_arrives(
        self, relay_results: dict[str, tuple[str, str]]
    ) -> None:
        # Arrange
        receiver_output, _ = relay_results["trusted"]

        # Assert
        assert "AGENTHOSTMARKER" in receiver_output, (
            "the relay did not forward agent-host telemetry over verified TLS"
        )

    def test_given_a_trusted_relay_run_when_the_span_arrives_then_agent_host_identity_is_kept(
        self, relay_results: dict[str, tuple[str, str]]
    ) -> None:
        # Arrange
        receiver_output, _ = relay_results["trusted"]

        # Assert
        assert "copilot-agent-host" in receiver_output

    @pytest.mark.parametrize("case", [entry.name for entry in RELAY_CASES if not entry.forwards])
    def test_given_a_rejected_transport_case_when_the_relay_runs_then_nothing_reaches_the_receiver(
        self, relay_results: dict[str, tuple[str, str]], case: str
    ) -> None:
        # Arrange
        receiver_output, _ = relay_results[case]

        # Assert
        assert "AGENTHOSTMARKER" not in receiver_output, (
            f"the {case} case reached the fleet receiver anyway"
        )

    def test_given_a_wrong_bearer_token_when_the_relay_forwards_then_the_receiver_answers_401(
        self, relay_results: dict[str, tuple[str, str]]
    ) -> None:
        # Arrange
        _, relay_output = relay_results["wrong-bearer"]

        # Assert
        assert "401" in relay_output or "unauthorized" in relay_output.lower()

    @pytest.mark.parametrize("case", ["untrusted-ca", "hostname-mismatch"])
    def test_given_a_bad_certificate_case_when_the_relay_dials_then_a_tls_failure_is_logged(
        self, relay_results: dict[str, tuple[str, str]], case: str
    ) -> None:
        # Arrange
        _, relay_output = relay_results[case]

        # Assert
        assert "certificate" in relay_output.lower() or "tls" in relay_output.lower()
