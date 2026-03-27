# Ship Workflow

Universal shipping protocol for `/autoresearch:ship`. Handles code PRs, releases, deployments, and content publishing through a unified 8-phase workflow.

---

## Shipment Types

| Type | Description | Auto-detect Signal |
|---|---|---|
| `code-pr` | Create a pull request | Feature branch with commits ahead of main |
| `code-release` | Tag and release a version | Version bump in manifest |
| `deployment` | Deploy to an environment | Dockerfile/serverless.yml present |
| `content` | Publish content (docs, posts) | Markdown/content files changed |

## Flags

| Flag | Description | Default |
|---|---|---|
| `--dry-run` | Simulate without executing | false |
| `--auto` | Skip confirmation prompts | false |
| `--force` | Skip pre-flight checks | false |
| `--rollback` | Roll back last shipment | false |
| `--monitor` | Monitor post-ship health | false |

---

## Phase 1: Identify

Auto-detect type and target from context if not specified. Validate the shipment makes sense (branch exists, version bumped, build available, content valid).

---

## Phase 2: Inventory

Catalog changes and classify each as: breaking / feature / fix / internal. This drives changelog, version bump type, reviewer assignment, and testing requirements.

```bash
# Per type: git log/diff vs base or last tag, ls build artifacts, or list changed content files
```

---

## Phase 3: Checklist

### Universal Checks
All tests pass, no type/lint errors, no uncommitted changes, branch up to date, no merge conflicts.

### Type-Specific Checks

| Type | Key Checks |
|---|---|
| `code-pr` | Branch naming, clean commits, PR description, reviewers, CI |
| `code-release` | Version bumped, changelog updated, tag convention, release notes |
| `deployment` | Build succeeds, env vars configured, migrations ready, rollback plan, health endpoint |
| `content` | Spell-checked, links valid, images optimized, metadata complete |

If any check fails: `--force` skips with warning, otherwise stop and suggest `/autoresearch:fix`.

---

## Phase 4: Prepare

| Type | Actions |
|---|---|
| `code-pr` | Rebase/merge base, generate PR title + body from change inventory |
| `code-release` | Bump version if needed, update changelog, create release commit + tag |
| `deployment` | Build artifact, validate output |
| `content` | Build/render content, validate, stage assets |

---

## Phase 5: Dry-Run

Unless `--auto`, always dry-run first. Show summary of what will ship. Ask confirmation.

---

## Phase 6: Ship

| Type | Execution |
|---|---|
| `code-pr` | `git push -u origin <branch>` then `gh pr create --title ... --body ... --base main` |
| `code-release` | `git push origin main` + tag, then `gh release create` |
| `deployment` | Execute platform-specific deploy (Vercel/AWS/Docker/Heroku). Capture deployment ID/URL |
| `content` | Platform-specific publish (static build, CMS API, content branch push) |

---

## Phase 7: Verify

| Type | Verification |
|---|---|
| `code-pr` | `gh pr view` + `gh pr checks` — report PR URL and CI status |
| `code-release` | Verify tag on remote + `gh release view` |
| `deployment` | Health check endpoint + smoke test |
| `content` | Verify published content accessible, links and formatting correct |

---

## Phase 8: Log

Record in `autoresearch-results.tsv` as `ship-N` iteration. Metric: 1 (shipped) or 0 (failed).

Print summary: type, target, URL, CI status, files changed, next steps.

---

## Rollback (`--rollback`)

| Type | Action |
|---|---|
| `code-pr` | `gh pr close <number>` |
| `code-release` | `gh release delete` + `git push origin --delete <tag>` |
| `deployment` | Platform-specific rollback (Vercel rollback / kubectl rollout undo / etc.) |
| `content` | Unpublish or revert — platform-specific |

---

## Monitor (`--monitor`)

For deployments: health check every 60s for 5 minutes. If fails, alert and suggest/auto rollback. If error rate increases significantly, suggest rollback.

---

## Integration with Autoresearch

Ship is the natural endpoint of an autoresearch run. Reads experiment results to generate PR descriptions, include metric improvements in release notes, and document the optimization journey.
