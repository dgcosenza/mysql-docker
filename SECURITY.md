# Security Policy

Maintained by **Daniel G. Cosenza from FNX Labs**.

## Supported Versions

Only the latest daily build of the MySQL 8.4 LTS track receives security updates (`latest`, `8.4`). Immutable date-stamped tags (`8.4.x-YYYYMMDD`) are frozen for reproducibility.

## Vulnerability Scanning & Gates

- **Trivy** (OS + libraries): SARIF uploaded to GitHub Code Scanning; table and JSON reports retained for 90 days; **blocking hard gate** on any fixable `CRITICAL` or `HIGH` finding.
- **Grype**: **blocking hard gate** (`only-fixed: true`, severity cutoff `high`); table report retained for 90 days.
- **SBOM & Provenance**: SPDX-JSON SBOM via Syft plus build provenance JSON retained for 90 days.

## Reporting a Vulnerability

**Do not open a public issue** for security vulnerabilities.

Report privately through GitHub Security Advisories: open the repository's **Security** tab or submit a private advisory directly at [dgcosenza/mysql-docker Security Advisories](https://github.com/dgcosenza/mysql-docker/security/advisories/new).

For upstream MySQL Server vulnerabilities, follow the [Oracle Vulnerability Reporting Policy](https://www.oracle.com/corporate/security-practices/assurance/vulnerability/reporting.html).

Please include a description of the vulnerability, affected tag or digest, reproduction steps, and any suggested remediation. We aim to acknowledge reports within 48 hours.
