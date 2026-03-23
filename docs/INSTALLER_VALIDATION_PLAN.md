# Installer Validation Plan (Claude plugin)

## Why this plan exists
`scripts/install-autoresearch.sh` adds install/update/uninstall flows with both interactive and non-interactive modes. Validation should confirm safety, usability, and predictable CLI behavior.

## What was validated in the previous implementation
1. **Shell syntax sanity**
   - `bash -n scripts/install-autoresearch.sh`
2. **Help/usage path**
   - `./scripts/install-autoresearch.sh -h`
3. **Manual code review checks**
   - Option parsing (`--action`, `--source`, `--yes`, `--non-interactive`)
   - Interactive menu flow and confirmation prompts
   - Claude CLI presence check (`command -v claude`)

## Validation gaps identified
- No automated integration tests for:
  - install/update/uninstall command dispatch correctness
  - interactive branch behavior
  - failure-path behavior when `claude` is missing or command fails

## Proposed validation plan (next iteration)

### 1) Static checks (always)
- `bash -n scripts/install-autoresearch.sh`
- `shellcheck scripts/install-autoresearch.sh`

### 2) Behavioral tests with command stubbing
Use a temporary fake `claude` executable in PATH to capture and assert calls.

Test cases:
- `--action install --source . --yes --non-interactive` -> should call `claude plugin add .`
- `--action update --source . --yes --non-interactive` -> should call `claude plugin add .`
- `--action uninstall --yes --non-interactive` -> should call `claude plugin remove autoresearch`
- `--non-interactive` without `--action` -> should exit non-zero with clear error

### 3) Smoke tests in real environment (manual)
- Run install/update/uninstall against an actual Claude CLI setup.
- Verify plugin appears/disappears in Claude plugin list.

### 4) CI policy
At minimum, fail PR if syntax/static checks fail.
Prefer adding stub-based behavioral tests to CI once test harness is committed.

## Acceptance criteria
- All static checks pass.
- All stub-based behavioral tests pass.
- Manual smoke test confirms at least one full install -> update -> uninstall cycle.
