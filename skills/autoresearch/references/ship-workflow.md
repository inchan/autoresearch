# Ship Workflow

Universal shipping protocol for the `/autoresearch:ship` command. Handles code PRs, releases, deployments, and content publishing through a unified 8-phase workflow.

---

## Overview

Shipping is the final mile. The autoresearch loop optimizes; the ship workflow delivers. It applies the same systematic rigor to the release process.

**Input:** Target (what to ship) and type (how to ship it)
**Output:** Shipped artifact with verification

---

## Shipment Types

| Type | Description | Typical Target |
|---|---|---|
| `code-pr` | Create a pull request | Branch with changes |
| `code-release` | Tag and release a version | Main branch |
| `deployment` | Deploy to an environment | Build artifact |
| `content` | Publish content (docs, posts) | Content files |

---

## Flags

| Flag | Description | Default |
|---|---|---|
| `--dry-run` | Simulate the ship without executing | false |
| `--auto` | Skip confirmation prompts | false |
| `--force` | Skip pre-flight checks | false |
| `--rollback` | Roll back the last shipment | false |
| `--monitor` | Monitor post-ship health | false |

---

## Phase 1: Identify

Determine what is being shipped and how.

### Auto-Detection

```
If no type specified, detect from context:
  - Uncommitted changes on a feature branch -> code-pr
  - Version bump in package.json/Cargo.toml -> code-release
  - Deployment config present (Dockerfile, serverless.yml) -> deployment
  - Markdown/content files changed -> content

If no target specified:
  - code-pr: current branch
  - code-release: current version + bump
  - deployment: default environment (staging, then production)
  - content: changed content files
```

### Validation

```
Verify the shipment makes sense:
  code-pr:
    - Is there a branch with commits ahead of main?
    - Are there uncommitted changes that should be included?
  code-release:
    - Is the version number bumped?
    - Is the changelog updated?
  deployment:
    - Is the build artifact available?
    - Is the deployment target configured?
  content:
    - Are content files valid (markdown, etc.)?
    - Are assets (images, etc.) present?
```

---

## Phase 2: Inventory

Catalog everything that will be shipped.

### Change Inventory

```bash
# For code-pr: list all changes vs base branch
git log main..HEAD --oneline
git diff main..HEAD --stat

# For code-release: list all changes since last tag
git log $(git describe --tags --abbrev=0)..HEAD --oneline

# For deployment: list build artifacts
ls -la dist/ build/ out/ 2>/dev/null

# For content: list changed content files
git diff --name-only main..HEAD -- '*.md' '*.mdx' '*.rst'
```

### Impact Assessment

```
For each change, classify:
  - Breaking change? (API change, schema migration, config change)
  - New feature? (new endpoint, new UI component, new capability)
  - Bug fix? (regression fix, error handling, edge case)
  - Internal? (refactor, dependency update, CI change)

This classification drives:
  - Changelog generation
  - Version bump type (major/minor/patch)
  - Reviewer assignment
  - Testing requirements
```

---

## Phase 3: Checklist

Pre-flight checks before shipping.

### Universal Checks

```
1. [ ] All tests pass
2. [ ] No type errors
3. [ ] No lint violations
4. [ ] No uncommitted changes
5. [ ] Branch is up to date with base
6. [ ] No merge conflicts
```

### Type-Specific Checks

#### code-pr
```
1. [ ] Branch name follows convention
2. [ ] Commits are clean (squashed if needed)
3. [ ] PR description is drafted
4. [ ] Reviewers are identified
5. [ ] CI will pass (run checks locally first)
```

#### code-release
```
1. [ ] Version bumped in manifest (package.json, Cargo.toml, etc.)
2. [ ] Changelog updated
3. [ ] No unreleased breaking changes without major version bump
4. [ ] Tag name follows convention (v1.2.3)
5. [ ] Release notes drafted
```

#### deployment
```
1. [ ] Build succeeds
2. [ ] Environment variables configured
3. [ ] Database migrations ready (if any)
4. [ ] Rollback plan documented
5. [ ] Health check endpoint available
```

#### content
```
1. [ ] Content is spell-checked
2. [ ] Links are valid
3. [ ] Images are optimized
4. [ ] Metadata is complete (title, date, tags)
5. [ ] Preview looks correct
```

### Check Execution

```
Run all applicable checks automatically.
If any check fails:
  --force flag: skip and continue (with warning)
  No --force: stop and report the failure
  Suggest: /autoresearch:fix to resolve issues
```

---

## Phase 4: Prepare

Prepare the shipment artifact.

### code-pr

```bash
# Ensure branch is clean and up to date
git fetch origin main
git rebase origin/main  # or merge, depending on project convention

# Generate PR body
pr_title="<type>: <short description>"
pr_body="## Summary\n<bullet points from change inventory>\n\n## Changes\n<git log>\n\n## Testing\n<test results>"
```

### code-release

```bash
# Bump version (if not already done)
# Update changelog
# Create release commit
git add package.json CHANGELOG.md
git commit -m "chore: release v<version>"

# Create tag
git tag -a "v<version>" -m "Release v<version>"
```

### deployment

```bash
# Build the artifact
npm run build  # or make build, cargo build --release, etc.

# Validate the artifact
# (check file sizes, expected outputs, etc.)
```

### content

```bash
# Build/render content
# Validate output
# Stage assets
```

---

## Phase 5: Dry-Run

Simulate the ship to catch issues before committing.

### Always Dry-Run First

```
Unless --auto flag is set, ALWAYS do a dry-run first.

code-pr:
  Print the PR title, body, and target branch
  List files that will be included
  Show the diff summary

code-release:
  Print the version, tag, and changelog
  Show what will be included in the release

deployment:
  Print the deployment target and artifact
  List configuration changes
  Show the deployment plan

content:
  Print the content list and publication targets
  Show rendered previews (if possible)
```

### Dry-Run Verification

```
After showing the dry-run:
  If --auto: proceed automatically
  Otherwise: ask for confirmation

  "This is what will be shipped:
   <summary>

   Proceed? (yes/no)"
```

---

## Phase 6: Ship

Execute the actual shipment.

### code-pr

```bash
# Push the branch
git push -u origin <branch-name>

# Create the PR
gh pr create \
  --title "<title>" \
  --body "<body>" \
  --base main \
  --head <branch-name>
```

### code-release

```bash
# Push the tag
git push origin main
git push origin "v<version>"

# Create GitHub release (if applicable)
gh release create "v<version>" \
  --title "v<version>" \
  --notes "<release notes>"
```

### deployment

```bash
# Execute deployment
# This varies dramatically by infrastructure:
#   - Vercel: vercel --prod
#   - AWS: aws deploy ...
#   - Docker: docker push + kubectl apply
#   - Heroku: git push heroku main

# Always capture the deployment ID/URL for verification
```

### content

```bash
# Publish content
# This varies by platform:
#   - Static site: build + deploy
#   - CMS: API publish
#   - Git-based: push to content branch
```

---

## Phase 7: Verify

Confirm the shipment succeeded.

### code-pr

```bash
# Verify PR was created
gh pr view <number> --json state,title,url

# Check CI status
gh pr checks <number>

# Report:
#   PR #<number> created: <url>
#   CI status: pending/passing/failing
```

### code-release

```bash
# Verify tag exists
git ls-remote --tags origin | grep "v<version>"

# Verify GitHub release
gh release view "v<version>"

# Report:
#   Release v<version> published: <url>
```

### deployment

```bash
# Health check
curl -s <health-endpoint> | grep "ok"

# Smoke test
# Run a minimal test against the deployed service

# Report:
#   Deployment successful: <url>
#   Health check: passing
```

### content

```
# Verify published content is accessible
# Check links, images, formatting
# Report:
#   Content published: <url>
```

---

## Phase 8: Log

Record the shipment in the results log.

### Ship Log Entry

```
In autoresearch-results.tsv:
  iteration: ship-1
  commit: <commit hash>
  metric: 1 (shipped) or 0 (failed)
  delta: 1
  guard: pass/fail
  status: keep (shipped) or crash (failed)
  description: "ship(<type>): <description>"
```

### Ship Summary

```
Ship Complete:
  Type: code-pr
  Target: feature/add-auth branch -> main
  PR: #42 — https://github.com/org/repo/pull/42
  CI: passing
  Files: 8 changed (+320, -45)

  Next steps:
  - Wait for review
  - Address feedback if any
  - Merge when approved
```

---

## Rollback

When `--rollback` flag is set.

### code-pr

```bash
# Close the PR without merging
gh pr close <number>
```

### code-release

```bash
# Delete the tag and release
gh release delete "v<version>" --yes
git push origin --delete "v<version>"
```

### deployment

```bash
# Roll back to previous version
# This varies by infrastructure:
#   - Vercel: vercel rollback
#   - AWS: redeploy previous version
#   - Docker: kubectl rollout undo
#   - Heroku: heroku rollback
```

### content

```
# Unpublish or revert to previous version
# Platform-specific
```

---

## Monitor (--monitor flag)

Post-ship monitoring when `--monitor` flag is set.

### Health Monitoring

```
For deployments:
1. Run health check every 60 seconds for 5 minutes
2. If health check fails:
   - Alert: "Health check failed at <time>"
   - If --auto: trigger automatic rollback
   - If not --auto: suggest rollback
3. If all checks pass:
   - Report: "Deployment healthy after 5 minutes of monitoring"
```

### Error Rate Monitoring

```
If error tracking is available:
1. Compare error rate before and after deployment
2. If error rate increases significantly:
   - Alert: "Error rate increased by X% after deployment"
   - Suggest rollback
3. If stable:
   - Report: "Error rate stable post-deployment"
```

---

## Integration with Autoresearch

```
The ship workflow is the natural endpoint of an autoresearch run:

1. /autoresearch optimizes the code (many iterations)
2. /autoresearch:ship packages and delivers the result

The ship workflow reads the autoresearch results to:
- Generate PR descriptions from experiment summaries
- Include metric improvements in release notes
- Document the optimization journey in the changelog
```
