---
description: "Require canonical public package registries in dependency manifests and lockfiles for OSS reproducibility"
applyTo: '**/package.json, **/package-lock.json, **/npm-shrinkwrap.json, **/.npmrc, **/pyproject.toml, **/uv.lock, **/requirements*.txt'
---

# Public Dependency Feed Policy

## Outcome

Every committed dependency manifest and lockfile resolves from a canonical public package registry so external contributors and CI can restore the repository without private network or feed access.

## Required Practice

* Commit an `.npmrc` beside every `package.json` that npm installs from, and repeat the canonical registry settings in each one. npm reads project configuration only from the root it runs in, so a nested project ignores the repository-root `.npmrc` and resolves from whatever registry the machine supplies. Apply this to install roots only; a workspace member, a generated manifest, or a template that npm never installs separately does not need its own file.
* Generate npm lockfiles from `https://registry.npmjs.org/` and retain its canonical tarball URLs and integrity metadata.
* Keep every npm lockfile `integrity` value on `sha512`. Internal mirrors often omit `dist.integrity` and publish only `dist.shasum`, which makes npm record a `sha1` value and silently weakens verification to a collision-vulnerable hash. Rewriting a `resolved` URL back to the public registry does not repair a downgraded `integrity` value.
* Use public ecosystem sources for other package managers, such as PyPI, the public PyTorch index, GitHub releases, NuGet Gallery, PowerShell Gallery, crates.io, and the Go module proxy.
* Run `npm run lint:public-dependency-feeds` after changing dependency metadata.
* When machine or enterprise configuration redirects a package manager through an internal mirror, override it with the canonical public registry while generating committed lockfiles.
* Treat a package version available only from an internal mirror as unpublished for this OSS repository. Wait for a public release or select a publicly available version rather than committing an internal feed URL.

## Prohibited Sources

Do not commit dependency source URLs pointing at private or organization-scoped artifact feeds, corporate or machine-level package proxies, authenticated URLs, or URLs carrying registry credentials. Do not commit lockfile entries whose `integrity` value uses an algorithm weaker than `sha512`.

## Restricted Networks

When a network blocks the public registries, route installs through the approved proxy from your own environment and never from a tracked file.

* Set the override with an environment variable or a CLI flag. A user-level `~/.npmrc` is outranked by this repository's committed `.npmrc`, because npm resolves configuration in the order `cli > env > project .npmrc > user .npmrc > global`.
* Restrict proxied use to restore commands such as `npm ci`, `uv sync --frozen`, and `pip install -r`. They read committed lockfiles and verify committed hashes, and `npm ci` does not write `package-lock.json`. <!-- pip-install-ok -->
* Do not resolve dependencies through a proxy. `npm install`, `npm update`, `npm audit fix`, `uv lock`, and `uv add` write the proxy's own URLs into the lockfile, and an npm proxy that omits `dist.integrity` also downgrades the recorded integrity to `sha1`.
* Generate lockfile changes where the public registry is reachable. Dependabot covers version bumps of existing dependencies. To add a new dependency, edit the manifest, push the branch, and let an agent or CI job with direct public registry access produce the lockfile.
* Do not hand-repair a proxy-generated lockfile. Restoring the `resolved` URL leaves the weakened `integrity` value in place, and recomputing the hash from proxy-served bytes attests only to what the proxy returned.
* Keep the proxy address out of every tracked file, including `.npmrc`, workflows, and `devcontainer.json`.

## Stop Rule

If a required dependency is unavailable from an approved public registry, stop the dependency update and record the publication blocker. Do not substitute an internal mirror, private feed, unpublished tarball, or credentialed source.

## Validation

`npm run lint:public-dependency-feeds` must pass before dependency changes are complete. The PR validation workflow enforces the same check before dependency installation.
