# Core Principles

1. **One metric** — ONE number drives ALL decisions. No ambiguity. For multi-dimensional goals, create a composite.
2. **Mechanical measurement** — extractable by shell command, deterministic, no human judgment. Imperfect mechanical > perfect subjective.
3. **Fast verification** — < 30s: explore aggressively (70/30). 30s–5min: balanced (50/50). > 5min: conservative (30/70).
4. **Commit before verify** — enables clean `git revert HEAD --no-edit`. Rollback on failure is non-negotiable.
5. **Git is memory** — `git log` each iteration to learn what worked/failed. History + lessons = smarter across runs.
6. **Simplicity wins** — same metric + less code = keep. Complexity only increases when it buys metric improvement.
7. **Bold experiments are cheap** — one hypothesis, one modification, one verification. Failed experiments cost exactly one iteration.
