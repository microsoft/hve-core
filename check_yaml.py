import yaml, sys
files = [
  '.github/skills/security/sigstore/controls/cosign-sign.yml',
  '.github/skills/security/sigstore/controls/cosign-verify.yml',
  '.github/skills/security/sbom/controls/spdx-2.3.yml',
  '.github/skills/security/sbom/controls/cyclonedx-1.5.yml',
  '.github/skills/security/cisa-sscm/controls/acquire-vendor-attestation.yml',
  '.github/skills/security/cisa-sscm/controls/acquire-component-provenance.yml',
  '.github/skills/security/cisa-sscm/controls/acquire-vulnerability-history.yml',
  '.github/skills/security/cisa-sscm/controls/acquire-sbom-required.yml',
]
for f in files:
    try:
        with open(f) as fh: doc = yaml.safe_load(fh)
        if 'controls' in doc and len(doc['controls']) > 0:
            ctrl = doc['controls'][0]
            new_keys = [k for k in ['equivalentImplementations','applicability','alternativeGroup'] if k in ctrl]
            print(f'OK  {f} -> new fields present: {new_keys}')
        else:
            print(f'SKIP {f}: No "controls" array found')
    except Exception as e:
        print(f'FAIL {f}: {e}')
        # sys.exit(1) # Don't exit early, show all
