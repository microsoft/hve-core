---
title: TM7 test fixtures
description: Provenance, licensing, and maintenance rules for the TM7 test fixtures.
ms.date: 2026-08-07
ms.topic: reference
---

# TM7 test fixtures

Read-only inputs for the TM7 test suite. Nothing here is generated output, and
the generation runtime never writes to this directory.

## Provenance

Only `tmt-reference.tm7` is upstream-derived. The other fixtures were compared
against every `.tm7` in the upstream repository and match none of them.

* `tmt-reference.tm7` comes from `gholliday/tm7-cli`, `samples/demo.tm7`, and
  is MIT licensed. See the details below.
* `tmt-reference-threats.tm7` is first-party, authored for this repository.
* `expected.tm7` and `tmp-sample.tm7` are first-party pinned golden files.
* `comprehensive-spec.yaml` is first-party, a pinned regression snapshot of
  `docs/planning/threat-models/hve-core-comprehensive.yaml`.

### tmt-reference.tm7

* Upstream repository: <https://github.com/gholliday/tm7-cli>
* Upstream file: `samples/demo.tm7`
* Upstream revision: `715954acc5b0a42386d3c0a3a42cdf35c5f41cfc`
* Upstream license: MIT
* SHA-256 of the committed bytes, which equals the upstream digest:
  `8c01c931b70388915113bc1b814424ea3400913088af01ce26e62d945b784dc3`

The committed copy is byte-identical to upstream at 1,212,739 bytes. Verify it
with `git cat-file blob <rev>:<path> | sha256sum`, which reads the object store
directly.

Do not hash a working-tree copy. This file is stored with LF, and a checkout
with `core.autocrlf=true` rewrites three LF line breaks inside `<b:string>`
elements to CRLF, producing a 1,212,742-byte file that digests to
`a53a1510859b7f5f1958c5c1d665fdb8107fa9cf62a39050ce1baad6418a8b6f`. That value
was previously recorded here and in `THIRD-PARTY-NOTICES` as though it described
the redistributed file, which made the attribution unverifiable for anyone
checking out on a different platform.

The embedded knowledge base in this fixture originates from the Microsoft
threat-modeling templates (`default.tb7`), which are MIT licensed. Attribution
for both sources is recorded in the repository `THIRD-PARTY-NOTICES`.

## Maintenance

Fixture bytes are load-bearing. Tests assert on serializer member order and
document structure, so re-saving a fixture through the Threat Modeling Tool
changes results even when the model is semantically unchanged. Replace a
fixture only with a recorded reason, and update the checksums above in the
same change.

`comprehensive-spec.yaml` is an intentionally pinned snapshot taken from
`docs/planning/threat-models/hve-core-comprehensive.yaml`. It is a regression
baseline, not a mirror, and it is expected to diverge from the shipped spec as
that spec evolves. Tests assert on its structure, including its 80 threats, its
per-surface trust zones, and identifiers such as `AX-1`, `flow-04`, and
`flow-21`. Those assertions protect layout packing and threat population against
unintended generator changes, which requires a stable input rather than a moving
one. Resynchronize it only as a deliberate baseline change, in a commit that also
reviews and updates the affected count and identifier assertions in
`test_populate_tm7_threats.py`. Do not resynchronize it merely because it differs
from the shipped spec; that difference is the intended state.
