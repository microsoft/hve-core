#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Shared input policy for the bundled helper scripts.

Every helper takes a configurable endpoint or path from the environment or the
command line. This module is the single place those decisions are made, so a
helper cannot be hardened in one place and left open in another.

Nothing here makes an arbitrary PromQL or TraceQL query safe. It constrains
where a request may go and where a file may be written, not what is asked for.
"""

from __future__ import annotations

import http.client
import ipaddress
import os
import pathlib
import socket
import urllib.parse
import urllib.request
from typing import IO

__all__ = [
    "DEFAULT_ALLOWED_PORTS",
    "PolicyError",
    "check_url",
    "contain_path",
    "is_loopback_host",
    "open_url",
    "origin_of",
    "require_credentials",
    "resolve_addresses",
]


class PolicyError(ValueError):
    """Raised when an input is refused. No request and no write has occurred."""


# The local stack's published surfaces. A helper pointed somewhere else on the
# machine is more likely a mistake or a redirect than an intent.
DEFAULT_ALLOWED_PORTS = frozenset({3000, 3200, 4317, 4318, 9090})

_ALLOWED_SCHEMES = frozenset({"http", "https"})

# Headers that identify the caller to the origin they were addressed to. They
# are meaningless to a different origin and dangerous there.
_CREDENTIAL_HEADERS = frozenset({"authorization", "proxy-authorization", "cookie"})

_DEFAULT_PORTS = {"http": 80, "https": 443}


def origin_of(url: str) -> tuple[str, str, int]:
    """Return the normalized (scheme, host, port) triple for a URL.

    Normalization is the whole point. `http://h/x` and `http://h:80/x` are the
    same origin, and comparing raw parsed ports would call them different and
    strip credentials from a redirect that never left the origin that was
    given them.
    """
    parsed = urllib.parse.urlparse(url)
    scheme = parsed.scheme.lower()
    host = (parsed.hostname or "").lower()
    try:
        port = parsed.port
    except ValueError:
        port = None
    return scheme, host, port if port is not None else _DEFAULT_PORTS.get(scheme, -1)


def resolve_addresses(host: str) -> tuple[ipaddress.IPv4Address | ipaddress.IPv6Address, ...]:
    """Every address this host currently resolves to.

    An address literal resolves to itself. A name is resolved, because a name
    says nothing about where a connection goes: `localhost` can be redefined in
    a hosts file, and a name that looks local can answer with a routable
    address. Resolution failure is refused rather than treated as either
    answer.
    """
    literal = host.strip("[]")
    try:
        return (ipaddress.ip_address(literal),)
    except ValueError:
        pass

    try:
        infos = socket.getaddrinfo(host, None, type=socket.SOCK_STREAM)
    except (socket.gaierror, UnicodeError, ValueError) as exc:
        raise PolicyError(f"refusing '{host}': it does not resolve ({exc})") from exc

    addresses = {ipaddress.ip_address(info[4][0].split("%", 1)[0]) for info in infos}
    if not addresses:
        raise PolicyError(f"refusing '{host}': it resolves to no address")
    return tuple(sorted(addresses, key=str))


def is_loopback_host(host: str) -> bool:
    """Whether every address this host resolves to is on this machine.

    Every address, not any: a name answering with one loopback address and one
    routable address would otherwise be treated as local while a connection
    could still leave the machine.

    This narrows where a request may go. It does not prevent DNS rebinding,
    because the transport resolves the name again when it connects and may get
    a different answer than this check saw.
    """
    return all(address.is_loopback for address in resolve_addresses(host))


def check_url(
    url: str,
    *,
    allow_remote: bool = False,
    allowed_ports: frozenset[int] = DEFAULT_ALLOWED_PORTS,
) -> urllib.parse.ParseResult:
    """Return the parsed URL if policy permits it, otherwise raise PolicyError.

    Remote targets require both an explicit opt-in and HTTPS. A loopback target
    may stay on HTTP because it does not leave the machine.
    """
    try:
        parsed = urllib.parse.urlparse(url)
    except ValueError as exc:
        raise PolicyError(f"unparseable URL: {exc}") from exc

    if parsed.scheme not in _ALLOWED_SCHEMES:
        raise PolicyError(
            f"refusing scheme '{parsed.scheme or '(none)'}': only http and https are allowed"
        )

    # Credentials in the authority are refused rather than stripped, because
    # stripping them silently changes which identity the request is made as.
    if parsed.username is not None or parsed.password is not None:
        raise PolicyError("refusing a URL that carries credentials in its authority")

    try:
        host = parsed.hostname
        port = parsed.port
    except ValueError as exc:
        raise PolicyError(f"malformed authority: {exc}") from exc

    if not host:
        raise PolicyError("refusing a URL with no host")

    resolved_port = port if port is not None else (443 if parsed.scheme == "https" else 80)
    addresses = resolve_addresses(host)

    if all(address.is_loopback for address in addresses):
        if resolved_port not in allowed_ports:
            raise PolicyError(
                f"refusing local port {resolved_port}: expected one of "
                f"{', '.join(str(value) for value in sorted(allowed_ports))}"
            )
        return parsed

    if any(address.is_loopback for address in addresses):
        raise PolicyError(
            f"refusing '{host}': it resolves to both loopback and non-loopback addresses, "
            "so where a connection lands is not decidable here"
        )

    if not allow_remote:
        raise PolicyError(
            f"refusing non-loopback host '{host}'. "
            "Set COPILOT_OTEL_ALLOW_REMOTE=1 only if that target is disposable."
        )
    if parsed.scheme != "https":
        raise PolicyError(f"refusing plaintext http to remote host '{host}': use https")

    # An opted-in remote target must be genuinely remote. Private, link-local,
    # and metadata-service ranges are the addresses a redirect would choose to
    # reach something inside the network that never expected this request.
    internal = [address for address in addresses if not address.is_global]
    if internal:
        raise PolicyError(
            f"refusing remote host '{host}': it resolves to non-global "
            f"address(es) {', '.join(str(address) for address in internal)}"
        )
    return parsed


class _PolicyRedirectHandler(urllib.request.HTTPRedirectHandler):
    """Re-applies policy to every redirect target.

    A server that answers a permitted loopback request with a redirect to
    somewhere else would otherwise carry the request straight past the check
    that was made on the original URL.

    Rechecking the target is not enough on its own. The standard library
    carries `Authorization`, `Proxy-Authorization`, and `Cookie` onto the
    redirected request, so a permitted redirect to a different origin would
    hand that origin a credential it was never issued. Those headers are
    removed after the redirect request is built, and only when the normalized
    origin actually changed.
    """

    def __init__(self, *, allow_remote: bool, allowed_ports: frozenset[int]) -> None:
        self._allow_remote = allow_remote
        self._allowed_ports = allowed_ports

    def redirect_request(
        self,
        req: urllib.request.Request,
        fp: IO[bytes],
        code: int,
        msg: str,
        headers: http.client.HTTPMessage,
        newurl: str,
    ) -> urllib.request.Request | None:
        check_url(newurl, allow_remote=self._allow_remote, allowed_ports=self._allowed_ports)
        redirected = super().redirect_request(req, fp, code, msg, headers, newurl)
        if redirected is None:
            return None
        if origin_of(req.full_url) != origin_of(redirected.full_url):
            _strip_credential_headers(redirected)
        return redirected


def _strip_credential_headers(request: urllib.request.Request) -> None:
    """Remove credential headers from both stores urllib keeps them in.

    Keys are matched case-insensitively rather than by reproducing urllib's
    `str.capitalize()` convention, so this does not depend on how the header
    was spelled when it was added.
    """
    for store in (request.headers, request.unredirected_hdrs):
        for key in [name for name in store if name.lower() in _CREDENTIAL_HEADERS]:
            del store[key]


def open_url(
    request: urllib.request.Request | str,
    *,
    allow_remote: bool = False,
    allowed_ports: frozenset[int] = DEFAULT_ALLOWED_PORTS,
    timeout: int = 25,
) -> http.client.HTTPResponse:
    """Open a URL after checking it, and re-check every redirect it follows.

    The response is an `HTTPResponse` rather than a wider union because
    `check_url` admits only http and https, so no other handler can answer.
    """
    url = request if isinstance(request, str) else request.full_url
    check_url(url, allow_remote=allow_remote, allowed_ports=allowed_ports)
    # The empty ProxyHandler is explicit because build_opener adds to the default
    # chain: without it, the default handler reads HTTP_PROXY and routes even a
    # loopback request off-box, since proxy_bypass does not exempt loopback.
    opener = urllib.request.build_opener(
        _PolicyRedirectHandler(allow_remote=allow_remote, allowed_ports=allowed_ports),
        urllib.request.ProxyHandler({}),
    )
    return opener.open(request, timeout=timeout)


def contain_path(candidate: str | os.PathLike[str], root: str | os.PathLike[str]) -> pathlib.Path:
    """Return the resolved candidate if it stays inside root, else raise.

    Both sides are fully resolved first, so `..` segments and symlinks that
    point outside the root are caught rather than normalized away.
    """
    resolved_root = pathlib.Path(root).expanduser().resolve()
    resolved = pathlib.Path(candidate).expanduser()
    if not resolved.is_absolute():
        resolved = resolved_root / resolved
    resolved = resolved.resolve()

    if resolved != resolved_root and resolved_root not in resolved.parents:
        raise PolicyError(f"refusing a path outside {resolved_root}: {resolved}")
    return resolved


def require_credentials(*names: str) -> tuple[str, ...]:
    """Return the named environment values, or raise naming every missing one.

    Missing configuration and a rejected credential are different problems, and
    a helper that sends a request with an empty password reports the second
    when it means the first.
    """
    values = tuple(os.environ.get(name, "") for name in names)
    missing = [name for name, value in zip(names, values, strict=True) if not value]
    if missing:
        raise PolicyError(f"missing required environment variable(s): {', '.join(missing)}")
    return values
