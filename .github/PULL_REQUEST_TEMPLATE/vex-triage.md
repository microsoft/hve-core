# VEX Triage

## Summary

<!-- Brief overview of the CVEs addressed in this triage PR. -->

## Evidence Checklist

* [ ] Code citations provided (file path and line range for reachability evidence per CVE)
* [ ] Vulnerability details included (CVE ID, advisory URL, CVSS score per CVE)
* [ ] Reachability analysis completed (import path traced, dead code confirmed, or mitigation identified)
* [ ] Licensing compliance verified (data sourced from CC0/public domain sources; GHSA prose not quoted)

## CVE Assessments

<!-- Copy the block below for each CVE addressed in this PR. -->

### CVE-YYYY-NNNNN

<!-- Replace the heading above with the actual CVE ID. -->

**VEX Status:**

* [ ] `not_affected`
* [ ] `affected`
* [ ] `under_investigation`
* [ ] `fixed`

**Confidence Band:**

* [ ] High: not_affected (vulnerable symbol provably unreachable)
* [ ] High: affected (vulnerable symbol on a reachable execution path)
* [ ] Medium (symbol reachable in some configurations but ambiguous)
* [ ] Low (cannot determine reachability)
* [ ] Vendor-disputed (OSV/NVD shows dispute or CVSS < 4.0 with no known exploit)

**Impact Statement:**

<!-- Describe the impact of this CVE on hve-core consumers. Include the affected component, the vulnerable symbol, and whether any mitigation exists. -->

## Additional Context

<!-- Link to related advisories, remediation issues, or scan reports. -->
