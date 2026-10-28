---
name: github-feature-flow
description: >-
  Create and maintain Jarvis app GitHub issues, feature branches named
  feature/X-slug, and PRs into main with titles ending in (#X). Classifies
  new features as backend (jarvis), frontend (jarvis_app), or both and
  creates issues in the matching repo(s). Use when starting work from main,
  solving or continuing an existing GitHub issue, creating or updating an
  issue for a feature, opening a feature branch, linking a PR to an issue,
  or when the user asks to start the issue/branch/PR workflow.
---

# GitHub feature flow (Jarvis app)

Issue + feature branch + PR into `main`. All GitHub text in **English**.

## Repo scope for new features

Jarvis is split across two GitHub repos:

| Layer | Repo |
|---|---|
| Backend (API, agents, tools, server) | `JRealValdes/jarvis` |
| Frontend (client / app UI) | `JRealValdes/jarvis_app` (this repo) |

When the user asks for **new functionality** (new issues), decide which case applies **before** proposing:

1. **Frontend only** — UI screens, client navigation, Flutter/Dart presentation against an existing API → create **one** issue in `jarvis_app`.
2. **Backend only** — API, LangGraph, tools, config, Pi deploy, HF Space backend surface, etc. → create **one** issue in `jarvis` (`gh issue create --repo JRealValdes/jarvis ...`).
3. **Both** — new or changed API contract plus UI that consumes it → create **two** issues (one per repo) and **cross-link** them in each body.

In the proposal to the user, state the classification and which repo(s) will get issue(s). Do not create issues until they confirm (unless they already ordered the full flow).

Heuristics (when unclear, say so in the proposal and recommend the safer “both” split if an API change is likely):

- Touches `lib/`, Flutter widgets, navigation, theme, local client config with no new/changed server contract → frontend
- Touches `src/jarvis/`, FastAPI routes, MCP/tools, persistence → backend
- Needs new endpoints, response shapes, or auth flows **and** UI → both

## Start from `main` — new work (propose first)

If the user asks for a **new** change while on `main` (no issue number), **classify scope**, **propose**, then wait for confirmation:

1. Create GitHub issue(s) in the matching repo(s) (see above)
2. If this repo (`jarvis_app`) has an issue: create branch `feature/<N>-<slug>` from up-to-date `main` and develop there
3. If only `jarvis` is in scope: create that issue and do not open a frontend branch unless the user asks to continue in the backend repo

Do not create the issue(s) or branch until they agree (unless they already ordered the full flow).

## Work on an existing issue `#N` (from `main` or elsewhere)

If the user asks to solve, implement, or continue issue `#N`:

1. **Read the issue including comments:** `gh issue view <N> --comments` (add `--repo JRealValdes/jarvis` when the issue is on the backend). Treat title, body, checklist, **and comments** as requirements. Comments often hold handoffs, contract notes, or follow-ups missing from the body.
2. **Read the sibling issue when cross-linked:** if the body or comments link a related issue in the other repo (e.g. “Related backend issue: …”), also run `gh issue view <sibling> --comments` with the matching `--repo`. When implementing frontend work, prefer absorbing handoffs left on the backend sibling (and vice versa).
3. **Use the development branch** (only when working in the repo that owns that issue):
   - Look for an existing local or remote branch matching `feature/<N>-*` (or the branch linked under the issue’s Development section).
   - If it exists: check it out and pull latest (`git fetch` / `git pull`).
   - If it does not exist: create `feature/<N>-<slug>` from up-to-date `main` (slug from the issue title). Prefer `gh issue develop <N> --name feature/<N>-<slug> --checkout` when available; otherwise `git checkout -b` + `git push -u`.
4. **Develop on that branch** only — do not implement `#N` on `main`. Honor comment/handoff notes alongside the body. Update the issue body when new scope materially helps tracking.

## 1. Create the issue(s)

**Frontend** (`jarvis_app`, default cwd):

```bash
gh issue create --title "<English title>" --body-file <path-or-heredoc>
```

**Backend** (`jarvis`):

```bash
gh issue create --repo JRealValdes/jarvis --title "<English title>" --body-file <path-or-heredoc>
```

Body: short context, goal, checklist. English only.

When creating a **pair** (both repos), each body should:

- Scope only that repo’s work (frontend checklist vs backend checklist)
- Link the sibling issue once both URLs exist (create one, then the other with the first URL, then edit the first to add the second)

Example cross-link line:

```markdown
Related backend issue: https://github.com/JRealValdes/jarvis/issues/<N>
```

```markdown
Related frontend issue: https://github.com/JRealValdes/jarvis_app/issues/<M>
```

Record each issue number from the URL or `gh issue list` / `gh issue list --repo JRealValdes/jarvis`.

## 2. Create the branch

Slug: lowercase kebab-case from the issue title; drop punctuation; keep it short.

```bash
git fetch origin
git checkout main
git pull origin main
git checkout -b feature/<N>-<slug>
git push -u origin HEAD
```

Prefer linking development in GitHub when available:

```bash
gh issue develop <N> --name feature/<N>-<slug> --checkout
```

If `gh issue develop` is unavailable, the branch name + PR link is enough.

## 3. Develop

- Commit with Conventional Commits; only when the user asks to commit.
- If scope grows and it **materially** helps tracking, update the issue body (checklist / notes) via `gh issue edit <N> --body-file ...` **without asking**. Skip trivial or redundant edits.

## 4. Open a PR (only if the user asks)

```bash
gh pr create --title "<English summary> (#<N>)" --body-file <file>
```

**Title rule:** the title must end with a space and `(#N)` — e.g. `Restrict Local mode to admins only (#15)`.

**Body (English), include:**

```markdown
## Summary
- …

Closes #<N>.

## Test plan
- [ ] …
```

`Closes #<N>` associates the PR with the issue and closes it on merge. Use `Refs #<N>` instead if the PR is partial and must not close the issue.

Push with `-u` if the branch has no upstream yet.

## 5. After merge — branch cleanup

When a PR for `feature/<N>-*` is **merged**:

1. Expect the **remote** branch to be deleted next (usually by the user on the GitHub PR UI).
2. If `origin` still has the branch after merge, **propose** remote deletion and wait for confirmation — do not delete it unprompted.
3. When the remote branch is gone (or the user says they deleted it), check out `main`, then **ask before** deleting the local branch (`git branch -d feature/<N>-…`). After a squash/rebase merge, safe `-d` may fail; with user confirmation, `git branch -D` is OK.
4. End on `main` and **`git pull`** so local `main` includes the merge (`git fetch --prune` as needed).

## Checklist

```
- [ ] New work classified: backend / frontend / both; issues created in the matching repo(s) and cross-linked when both
- [ ] Issue exists (#N) in the owning repo, English; read with `--comments` before coding when working an existing issue; also read the cross-linked sibling issue (with comments) when present
- [ ] On feature/<N>-* in that repo (checked out or created), not on main
- [ ] Work landed on that branch
- [ ] Issue body updated only when useful
- [ ] PR title ends with (#N); body links Closes/Refs #N
- [ ] After merge: remote branch deleted (user UI or confirmed agent delete); local branch deleted only after confirmation; on main and pulled
```
