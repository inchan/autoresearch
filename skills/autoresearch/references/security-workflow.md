# Security Workflow

STRIDE + OWASP security audit protocol for `/autoresearch:security`. Applies the autoresearch iteration pattern to security testing.

**Input:** Scope (codebase or subsystem) and optional depth (quick/standard/deep)
**Output:** Security report with findings, recommendations, and coverage matrix

---

## Phase 1: Codebase Reconnaissance

Detect technology stack, database usage, authentication patterns, and API entry points. Map the architecture: entry points, data stores, external services, auth mechanisms, data flows.

---

## Phase 2: Asset Identification

| Sensitivity | Examples |
|---|---|
| HIGH | Credentials, PII, financial data, secrets |
| MEDIUM | Business logic, configuration, session data |
| LOW | Public data, static assets, documentation |

---

## Phase 3: Trust Boundary Mapping

Key boundaries: Client↔Server, App↔Database, App↔External API, User↔Admin, Public↔Authenticated, Service↔Service.

For each: what data crosses it, what validation exists, what guards it, what happens on guard failure.

---

## Phase 4: STRIDE Threat Model

| Threat | Description | Target |
|---|---|---|
| **S**poofing | Impersonation | Authentication |
| **T**ampering | Data/code modification | Integrity |
| **R**epudiation | Denying actions | Audit logging |
| **I**nfo Disclosure | Unauthorized data access | Confidentiality |
| **D**enial of Service | System unavailability | Availability |
| **E**levation of Privilege | Unauthorized access escalation | Authorization |

For each component/boundary, enumerate threats per STRIDE category. Document with ID, severity, and status.

---

## Phase 5: Attack Surface (OWASP Top 10)

| # | Category | Key Patterns to Detect |
|---|---|---|
| A01 | Broken Access Control | Missing auth checks, IDOR, path traversal |
| A02 | Cryptographic Failures | Weak algorithms, hardcoded secrets, plaintext |
| A03 | Injection | SQL, NoSQL, OS command, XPath |
| A04 | Insecure Design | Missing threat model, business logic flaws |
| A05 | Security Misconfiguration | Default creds, verbose errors |
| A06 | Vulnerable Components | Outdated deps with known CVEs |
| A07 | Auth Failures | Weak passwords, missing MFA, session fixation |
| A08 | Data Integrity Failures | Deserialization, CI/CD, unsigned updates |
| A09 | Logging Failures | Missing audit logs, log injection |
| A10 | SSRF | Unvalidated URLs, internal network access |

Use static analysis (pattern matching, dep scanning, secret scanning), dynamic analysis (fuzzing, auth bypass, authz testing), and code review (logic flow, race conditions, data flow tracing).

---

## Phase 6: Autonomous Testing Loop

Each iteration: select highest-priority untested threat → design test → execute → record result (vulnerable/mitigated/N/A) → document finding with severity and remediation → log.

---

## Composite Metric

```
score = (owasp_tested / 10) * 50 + (stride_tested / 6) * 30 + min(findings, 20)
```
Max 100. Direction: higher. Findings capped at 20 to prevent gaming.

---

## Report Structure

1. **Executive Summary** — date, scope, depth, finding counts by severity, coverage scores
2. **Findings** — each with severity, OWASP/STRIDE category, location, description, impact, evidence, remediation, status
3. **Coverage Matrix** — OWASP Top 10 + STRIDE tables with tested/findings/status
4. **Recommendations** — priority-ordered list with severity tags

---

## Depth Levels

| Depth | Time | Focus | Iterations |
|---|---|---|---|
| Quick | 10-15 min | Pattern matching, dep scan, secrets, OWASP Top 3 | ~15 |
| Standard | 30-60 min | Full OWASP + STRIDE for main components, auth review | ~30 |
| Deep | 1-2 hrs | Full STRIDE all components, data flow tracing, business logic, race conditions | ~60 |

Stop early if all categories tested, score plateaued 5+ iterations, or all threats tested. Always produce the report.
