# Security Workflow

STRIDE + OWASP security audit protocol for the `/autoresearch security` command. Applies the autoresearch iteration pattern to security testing: identify threats, test them systematically, build a comprehensive report.

---

## Overview

Security auditing is research. The same autonomous loop applies, but the metric is a composite security score and the goal is comprehensive threat coverage.

**Input:** Scope (codebase or subsystem) and optional depth (quick/standard/deep)
**Output:** Security report with findings, recommendations, and test results

---

## Phase 1: Codebase Reconnaissance

Understand the application's architecture before looking for vulnerabilities.

### Technology Stack Identification

```bash
# Detect frameworks, languages, dependencies
ls package.json requirements.txt Cargo.toml go.mod Gemfile 2>/dev/null
cat package.json 2>/dev/null | grep -E '"(express|fastify|next|react|vue|angular)"'
cat requirements.txt 2>/dev/null | grep -iE '(django|flask|fastapi|sqlalchemy)'

# Detect database usage
grep -rl 'sqlite\|postgres\|mysql\|mongo\|redis' --include="*.py" --include="*.ts" --include="*.js" . 2>/dev/null | head -10

# Detect authentication patterns
grep -rl 'jwt\|oauth\|session\|passport\|auth' --include="*.py" --include="*.ts" --include="*.js" . 2>/dev/null | head -10

# Detect API patterns
grep -rl 'router\|endpoint\|@app\.\|@api\.' --include="*.py" --include="*.ts" --include="*.js" . 2>/dev/null | head -10
```

### Architecture Mapping

```
Document:
1. Entry points (API routes, CLI commands, UI forms)
2. Data stores (databases, files, caches, sessions)
3. External services (APIs, message queues, cloud services)
4. Authentication/authorization mechanisms
5. Data flows (user input -> processing -> storage -> output)
```

---

## Phase 2: Asset Identification

Identify what needs protecting.

### Asset Categories

```
1. User data: PII, credentials, financial info
2. Application secrets: API keys, database passwords, JWT secrets
3. System resources: CPU, memory, disk, network
4. Business logic: algorithms, pricing, access control rules
5. Infrastructure: servers, databases, cloud resources
```

### Sensitivity Classification

```
For each asset:
  HIGH: Credentials, PII, financial data, secrets
  MEDIUM: Business logic, configuration, session data
  LOW: Public data, static assets, documentation
```

---

## Phase 3: Trust Boundary Mapping

Identify where trust levels change.

### Trust Boundaries

```
Common boundaries:
1. Client <-> Server (never trust client input)
2. Application <-> Database (SQL injection boundary)
3. Application <-> External API (untrusted responses)
4. User <-> Admin (privilege escalation boundary)
5. Public <-> Authenticated (authentication boundary)
6. Service <-> Service (lateral movement boundary)
```

### Boundary Analysis

```
For each boundary:
  What data crosses it?
  What validation exists?
  What authentication/authorization guards it?
  What happens if the guard fails?
```

---

## Phase 4: STRIDE Threat Model

Apply STRIDE to each component and boundary.

### STRIDE Categories

| Threat | Description | Target |
|---|---|---|
| **S**poofing | Pretending to be someone else | Authentication |
| **T**ampering | Modifying data or code | Data integrity |
| **R**epudiation | Denying actions were performed | Audit logging |
| **I**nformation Disclosure | Exposing data to unauthorized parties | Confidentiality |
| **D**enial of Service | Making the system unavailable | Availability |
| **E**levation of Privilege | Gaining unauthorized access | Authorization |

### Threat Enumeration

```
For each component/boundary, ask:
  S: Can an attacker impersonate a legitimate user/service?
  T: Can an attacker modify data in transit or at rest?
  R: Can an attacker perform actions without audit trail?
  I: Can an attacker access data they shouldn't see?
  D: Can an attacker crash or slow the system?
  E: Can an attacker gain higher privileges than intended?

Document each identified threat:
  Threat ID: S-001
  Category: Spoofing
  Component: /api/login
  Description: No rate limiting on login attempts enables brute force
  Severity: HIGH
  Status: untested
```

---

## Phase 5: Attack Surface Map

### OWASP Top 10 Mapping

Map the codebase against OWASP Top 10 (2021):

| # | Category | What to Look For |
|---|---|---|
| A01 | Broken Access Control | Missing auth checks, IDOR, path traversal |
| A02 | Cryptographic Failures | Weak algorithms, hardcoded secrets, plaintext storage |
| A03 | Injection | SQL, NoSQL, OS command, LDAP, XPath injection |
| A04 | Insecure Design | Missing threat model, business logic flaws |
| A05 | Security Misconfiguration | Default credentials, verbose errors, unnecessary features |
| A06 | Vulnerable Components | Outdated dependencies with known CVEs |
| A07 | Auth Failures | Weak passwords, missing MFA, session fixation |
| A08 | Data Integrity Failures | Deserialization, CI/CD, unsigned updates |
| A09 | Logging Failures | Missing audit logs, log injection, no alerting |
| A10 | SSRF | Unvalidated URLs, internal network access |

### Code Pattern Detection

```
Patterns to search for:

# SQL Injection
grep -rn 'f".*SELECT.*{' --include="*.py"
grep -rn "execute.*\+" --include="*.py" --include="*.js"

# Command Injection
grep -rn 'os\.system\|subprocess\.call\|exec(' --include="*.py"
grep -rn 'child_process\|exec(' --include="*.js" --include="*.ts"

# Path Traversal
grep -rn 'open.*\+\|readFile.*\+\|path\.join.*user' --include="*.py" --include="*.js"

# Hardcoded Secrets
grep -rn 'password\s*=\s*["\x27]' --include="*.py" --include="*.js" --include="*.ts"
grep -rn 'secret\s*=\s*["\x27]\|api_key\s*=\s*["\x27]' --include="*.py" --include="*.js"

# XSS
grep -rn 'innerHTML\|dangerouslySetInnerHTML\|v-html' --include="*.js" --include="*.ts" --include="*.vue"

# Insecure Deserialization
grep -rn 'pickle\.loads\|yaml\.load\b\|eval(' --include="*.py"
grep -rn 'JSON\.parse.*user\|deserialize' --include="*.js" --include="*.ts"
```

---

## Phase 6: Autonomous Testing Loop

Apply the autoresearch iteration pattern to security testing.

### Test Iteration

```
For each iteration:
1. Select the highest-priority untested threat
2. Design a test for that threat:
   - Can the vulnerability be triggered?
   - What's the impact if exploited?
   - Is there an existing mitigation?
3. Run the test (code analysis, pattern matching, or actual testing)
4. Record the result: vulnerable, mitigated, not applicable
5. If vulnerable: document the finding with severity and remediation
6. Log the iteration
```

### Test Types

```
Static Analysis (fast, automated):
  - Pattern matching for known-bad code patterns
  - Dependency vulnerability scanning
  - Configuration review
  - Secret scanning

Dynamic Analysis (if possible):
  - Input fuzzing on entry points
  - Authentication bypass attempts
  - Authorization boundary testing
  - Error handling verification

Code Review (manual by agent):
  - Logic flow analysis
  - Race condition detection
  - Data flow tracing
  - Trust boundary validation
```

---

## Composite Metric

The security audit uses a composite metric to track progress:

### Formula

```
score = (owasp_tested / 10) * 50 + (stride_tested / 6) * 30 + min(findings, 20)

Where:
  owasp_tested = number of OWASP Top 10 categories tested (0-10)
  stride_tested = number of STRIDE categories tested (0-6)
  findings = number of security findings documented (capped at 20)

Maximum possible score: 50 + 30 + 20 = 100

Direction: higher (more coverage and more findings = better audit)
```

### Metric Breakdown

```
Coverage component (80% of max score):
  OWASP coverage: up to 50 points (5 per category tested)
  STRIDE coverage: up to 30 points (5 per category tested)

Findings component (20% of max score):
  Each documented finding: +1 point (up to 20)
  This incentivizes thoroughness, not just coverage

Note: findings are capped to prevent gaming (fabricating findings)
```

### Tracking Progress

```
Iteration 1:  score = (1/10)*50 + (1/6)*30 + 2 = 5 + 5 + 2 = 12
Iteration 5:  score = (3/10)*50 + (3/6)*30 + 5 = 15 + 15 + 5 = 35
Iteration 10: score = (6/10)*50 + (5/6)*30 + 10 = 30 + 25 + 10 = 65
Iteration 15: score = (9/10)*50 + (6/6)*30 + 15 = 45 + 30 + 15 = 90
```

---

## Phase 7: Report Structure

### Executive Summary

```markdown
## Security Audit Report

**Date:** <date>
**Scope:** <scope>
**Depth:** quick | standard | deep
**Auditor:** autoresearch (autonomous)

### Summary

- **Critical findings:** N
- **High findings:** N
- **Medium findings:** N
- **Low findings:** N
- **OWASP coverage:** N/10 categories
- **STRIDE coverage:** N/6 categories
- **Composite score:** N/100
```

### Finding Format

```markdown
### Finding: <title>

- **Severity:** Critical | High | Medium | Low
- **Category:** OWASP A0X / STRIDE category
- **Location:** <file:line>
- **Description:** What the vulnerability is
- **Impact:** What an attacker could do
- **Evidence:** Code snippet or test result
- **Remediation:** How to fix it
- **Status:** Open | Mitigated | False Positive
```

### Coverage Matrix

```markdown
### OWASP Top 10 Coverage

| # | Category | Tested | Findings | Status |
|---|---|---|---|---|
| A01 | Broken Access Control | Yes | 2 | Findings |
| A02 | Cryptographic Failures | Yes | 1 | Finding |
| A03 | Injection | Yes | 0 | Clean |
| ... | ... | ... | ... | ... |

### STRIDE Coverage

| Category | Tested | Findings | Status |
|---|---|---|---|
| Spoofing | Yes | 1 | Finding |
| Tampering | Yes | 0 | Clean |
| ... | ... | ... | ... |
```

### Recommendations

```markdown
### Recommendations (Priority Order)

1. **[CRITICAL]** Fix SQL injection in user search endpoint (A03)
2. **[HIGH]** Add rate limiting to authentication endpoints (S-001)
3. **[HIGH]** Remove hardcoded API key from config.py (A02)
4. **[MEDIUM]** Add CSRF protection to state-changing endpoints (A01)
5. **[LOW]** Enable security headers (X-Frame-Options, CSP) (A05)
```

---

## Depth Levels

### Quick (10-15 minutes)

```
- Pattern matching for known-bad code patterns
- Dependency vulnerability check
- Hardcoded secret scan
- OWASP Top 3 (A01, A02, A03) focus
- ~10 iterations
```

### Standard (30-60 minutes)

```
- All Quick checks plus:
- Full OWASP Top 10 coverage
- STRIDE threat model for main components
- Authentication/authorization review
- Input validation audit
- ~25 iterations
```

### Deep (1-2 hours)

```
- All Standard checks plus:
- Full STRIDE for every component
- Data flow tracing for all entry points
- Business logic review
- Race condition analysis
- Third-party integration security
- ~50+ iterations
```

---

## Iteration Stopping

```
The security audit uses bounded iterations based on depth:
  Quick:    max 15 iterations
  Standard: max 30 iterations
  Deep:     max 60 iterations

Stop early if:
  - All OWASP categories tested AND all STRIDE categories tested
  - Score has plateaued for 5+ iterations
  - All identified threats have been tested

Always produce the report, regardless of when stopping occurs.
```
