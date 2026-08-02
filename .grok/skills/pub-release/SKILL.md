---
name: pub-release
description: >
  Guides publishing a Flutter/Dart package to pub.dev with a release checklist
  (CHANGELOG, README, docs), version policy (breaking changes as beta first,
  bugfixes as stable, promote beta to full after 1 week), and GitHub Issues
  feedback collection. Use when the user runs /pub-release, or asks to publish
  to pub.dev, cut a release, promote a beta, ship a bugfix version, or prep
  package release docs.
---

# pub-release

Agent instructions for releasing this Dart/Flutter package to [pub.dev](https://pub.dev).
Follow every phase in order. Do **not** publish until the user explicitly confirms
the final publish step.

## Version policy (non-negotiable)

| Change type | Channel | Version pattern | Notes |
|---|---|---|---|
| **Breaking change** | Beta first | `X.Y.Z-beta.N` | Never ship breaking API/SDK/behavior as stable on first cut |
| **Feature** (non-breaking) | Prefer beta, or patch/minor stable if low risk | `X.Y.Z-beta.N` or `X.Y.0` | Prefer beta for large features |
| **Bugfix only** | Stable | `X.Y.Z` (patch) | Ship as full release when no breaking changes |
| **Beta → full** | Stable after soak | Drop `-beta.N` → `X.Y.Z` | Only after **≥ 7 days** on pub.dev and feedback review |

SemVer rules for this package:

- Breaking → bump major or keep pre-release under the intended stable (`1.4.5-beta.N` → later `1.4.5`)
- Feature → minor (or stay on beta track for the next stable)
- Bugfix → patch
- Pre-release identifiers: use `-beta.1`, `-beta.2`, … (pub.dev pre-release ordering)

If the change set includes **any** breaking item, the whole release is **beta**.

## Release modes

Detect or ask which mode:

1. **beta** — new pre-release (breaking and/or large features)
2. **stable-bugfix** — patch with only fixes
3. **promote-beta** — promote an existing beta to full after 1-week soak
4. **docs-only** — no version bump publish; update docs only (rare)

---

## Phase 0 — Orient

1. Read `pubspec.yaml` for current `name`, `version`, `environment`, `homepage`/`repository`.
2. Read top of `CHANGELOG.md` for the latest published/unreleased notes.
3. `git status` / `git log` / `git diff` vs last tag — what actually changed.
4. List open GitHub issues/PRs that this release claims to fix (`gh issue list`, `gh pr list`).
5. State the chosen **mode**, **from version → to version**, and a one-line rationale. Get user confirmation if ambiguous.

---

## Phase 1 — Classify the change set

Build a short table:

| Item | Breaking? | Fix / Feature / Docs | Linked issue |
|---|---|---|---|

Rules:

- API removals/renames, min SDK/Flutter bumps, platform-view strategy changes, default behavior flips → **breaking**
- Pure crash/layout/leak fixes with public API unchanged → **bugfix**
- If mixed breaking + fixes → **beta** (list breaking first in CHANGELOG)

---

## Phase 2 — Documentation checklist (must all pass)

Work through every item. Mark `[x]` / `[ ]` in your reply to the user before publish.

### 2.1 CHANGELOG.md

- [ ] New section at top: `## <version>` matching `pubspec.yaml` exactly
- [ ] Breaking changes marked `**BREAKING**: …` and listed first
- [ ] Each user-facing fix/feature has a clear bullet
- [ ] Issue/PR links: `[#N](https://github.com/<owner>/<repo>/issues/N)` (or `/pull/N`)
- [ ] No “WIP”, “todo”, or empty sections
- [ ] Older entries left intact (do not rewrite published history unless correcting a factual error)

### 2.2 README.md

- [ ] Install snippet uses a version compatible with this release (or `^` range that includes it)
- [ ] New/changed public APIs documented with examples
- [ ] Breaking changes called out (migration notes or “Breaking” subsection)
- [ ] Removed or renamed APIs no longer shown as current usage
- [ ] Platform requirements (min iOS / Android / Flutter / Dart) match `pubspec.yaml` / native configs
- [ ] Links (homepage, issues) still valid

### 2.3 Other package docs

- [ ] Public API dartdoc still accurate (`///` on new/changed public members)
- [ ] `example/` still builds and demonstrates important APIs
- [ ] Example `pubspec.yaml` path/dependency still correct for local path or published name
- [ ] Native notes if needed (ProGuard, Privacy Manifest, min SDK) in README or `android/`/`ios/` docs
- [ ] `LICENSE` present and unchanged unless intentional
- [ ] Topics / description in `pubspec.yaml` still accurate

### 2.4 Version files stay in sync

- [ ] `pubspec.yaml` `version:`
- [ ] `CHANGELOG.md` heading
- [ ] Any hardcoded version strings in README/example (if present)
- [ ] Git tag plan: `v<version>` or `<version>` — match existing tag style in the repo

Reference: [references/checklist.md](references/checklist.md)

---

## Phase 3 — Quality gates (before any publish)

Run from package root (adjust if monorepo):

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

If the package has an example:

```bash
cd example && flutter pub get && flutter analyze
```

Optional but recommended for plugins:

```bash
# Android unit tests if present
cd android && ./gradlew test  # or project-specific command
```

Also:

```bash
dart pub publish --dry-run
```

Fix all failures before continuing. Dry-run must report no blockers.

---

## Phase 4 — GitHub Issues feedback loop

### When shipping a **beta**

1. Open (or update) a tracking issue titled roughly:
   `Beta feedback: <package> <version>`
2. Body must include:
   - What changed (summary + link to CHANGELOG section)
   - Breaking changes / migration steps
   - How to try: dependency override or version pin (`package: X.Y.Z-beta.N`)
   - Ask for: platform, Flutter version, repro, expected vs actual
   - Explicit note: target full release after **≥ 7 days** if no critical regressions
3. Label appropriately if labels exist (`beta`, `feedback`, `release`)
4. Link related fixed issues in the tracking issue
5. Comment on major fixed issues: “Included in `<version>` (beta) — please verify”

```bash
gh issue create --title "Beta feedback: <name> <version>" --body-file - <<'EOF'
...
EOF
```

### When shipping a **stable bugfix**

1. Comment on fixed issues that the fix is on pub.dev as `<version>`
2. Close issues only when the fix is confirmed shipped (or per repo convention: close with “fixed in …” and let maintainers close)

### When **promoting beta → full**

1. Search issues for beta feedback since beta publish date:

```bash
gh issue list --search "beta feedback OR regression OR <version-base>" --state all --limit 50
gh issue list --label "bug" --state open --limit 50
```

2. Summarize to the user:
   - Critical regressions? → **do not promote**; cut `beta.N+1` instead
   - Non-blocking issues? → file follow-ups, proceed if user agrees
3. Comment on the beta tracking issue that full `X.Y.Z` is published; close if resolved
4. Thank reporters on useful feedback issues

---

## Phase 5 — Version bump

1. Edit `pubspec.yaml` `version:`
2. Ensure CHANGELOG top section matches
3. Commit only when user asks to commit (do not force git_write)

Suggested commit message style:

```
release: <version>
```

or

```
chore(release): <version>
```

Tag after publish success (or immediately before, per repo habit — prefer **after** successful `dart pub publish` so tags match live versions):

```bash
git tag v<version>   # or match existing tag pattern
git push origin HEAD --tags
```

Only push/tag when the user approves.

---

## Phase 6 — Publish to pub.dev

**Stop and confirm with the user** before running publish.

```bash
dart pub publish --dry-run   # once more if anything changed
dart pub publish
```

Notes:

- Requires logged-in publisher (`dart pub token` / browser auth as configured)
- Publisher must have permission on the pub.dev package
- Pre-release versions (`-beta.N`) are visible on pub.dev but clients need an explicit constraint to take them (good)
- After publish, verify: `https://pub.dev/packages/<name>/versions`

Do **not** re-publish the same version. Versions are immutable.

---

## Phase 7 — Promote beta → full (after 1 week)

Trigger when user asks to promote, or when reviewing an aged beta.

1. Confirm beta version exists on pub.dev and **published date ≥ 7 days ago**
2. Run Phase 4 feedback review (blockers → new beta, not promote)
3. Set version to stable `X.Y.Z` (same numbers as beta base, no `-beta.N`)
4. CHANGELOG:
   - Add `## X.Y.Z` noting promotion from `X.Y.Z-beta.N` and any post-beta fixes
   - If identical to last beta: “Stable release of X.Y.Z-beta.N after soak period.”
5. Re-run Phase 2–3 checklists
6. Publish stable, then Phase 4 close-out comments

If post-beta fixes landed:

- Either promote with those fixes listed under `X.Y.Z`, or
- Ship another beta and restart the 7-day clock (prefer restart if fixes are risky)

---

## Phase 8 — Post-release

- [ ] pub.dev version page shows the new version
- [ ] GitHub release notes optional: `gh release create v<version> --notes-file ...`
- [ ] Tracking/feedback issues updated
- [ ] Tell the user the install constraint:

**Stable:**

```yaml
dependencies:
  <package>: ^X.Y.Z
```

**Beta:**

```yaml
dependencies:
  <package>: X.Y.Z-beta.N
```

---

## Decision shortcuts

```
Is there a BREAKING change?
  YES → beta (never direct stable)
  NO  → only bugfixes?
          YES → stable patch
          NO  → features?
                  large / risky → beta
                  small / safe  → minor/patch stable (confirm with user)

Is this a promote-beta request?
  beta age < 7 days → refuse promote; report days remaining
  open critical regressions → new beta, do not promote
  else → stable X.Y.Z
```

---

## Safety

- Never `dart pub publish` without explicit user approval for that exact version
- Never force-push tags or rewrite published CHANGELOG history casually
- Never publish with failing analyze/tests or failed dry-run
- Never skip README/CHANGELOG sync “to do later”
- If publisher credentials missing, stop and instruct the user to auth — do not try to bypass

## Communication with the user

At each major gate, report:

1. Mode + version transition
2. Checklist status (pass/fail list)
3. Feedback issue status
4. Exact command you want to run next
5. Wait for approval on publish / tag / push
