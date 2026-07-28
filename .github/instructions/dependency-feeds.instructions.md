---
description: "Require canonical public package registries in dependency manifests and lockfiles for OSS reproducibility"
applyTo: '**/package.json, **/package-lock.json, **/npm-shrinkwrap.json, **/.npmrc, **/pyproject.toml, **/uv.lock, **/requirements*.txt'
---

# Public Dependency Feed Policy

## Outcome

Every committed dependency manifest and lockfile resolves from a canonical public package registry so external contributors and CI can restore the repository without private network or feed access.

## Required Practice

* Generate npm lockfiles from `https://registry.npmjs.org/` and retain its canonical tarball URLs and integrity metadata.
* Keep every npm lockfile `integrity` value on `sha512`. Internal mirrors often omit `dist.integrity` and publish only `dist.shasum`, which makes npm record a `sha1` value and silently weakens verification to a collision-vulnerable hash. Rewriting a `resolved` URL back to the public registry does not repair a downgraded `integrity` value.
* Use public ecosystem sources for other package managers, such as PyPI, the public PyTorch index, GitHub releases, NuGet Gallery, PowerShell Gallery, crates.io, and the Go module proxy.
* Run `npm run lint:public-dependency-feeds` after changing dependency metadata.
* When machine or enterprise configuration redirects a package manager through an internal mirror, override it with the canonical public registry while generating committed lockfiles.
* Treat a package version available only from an internal mirror as unpublished for this OSS repository. Wait for a public release or select a publicly available version rather than committing an internal feed URL.

## Prohibited Sources

Do not commit dependency source URLs pointing at private or organization-scoped artifact feeds, corporate or machine-level package proxies, authenticated URLs, or URLs carrying registry credentials. Do not commit lockfile entries whose `integrity` value uses an algorithm weaker than `sha512`.

## Stop Rule

If a required dependency is unavailable from an approved public registry, stop the dependency update and record the publication blocker. Do not substitute an internal mirror, private feed, unpublished tarball, or credentialed source.

## Validation

`npm run lint:public-dependency-feeds` must pass before dependency changes are complete. The PR validation workflow enforces the same check before dependency installation.
