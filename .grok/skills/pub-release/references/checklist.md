# Release checklist (copy into PR or agent reply)

Package: _______________  
Mode: beta | stable-bugfix | promote-beta | docs-only  
From → To: _______________ → _______________  
Date: _______________

## Classify

- [ ] Change set inventoried (breaking / feature / bugfix / docs)
- [ ] Mode matches version policy (breaking ⇒ beta; bugfix-only ⇒ stable; promote only after ≥7 days)

## Docs

- [ ] `pubspec.yaml` version updated
- [ ] `CHANGELOG.md` top section matches version
- [ ] Breaking items marked `**BREAKING**`
- [ ] Issue/PR links in CHANGELOG
- [ ] README install snippet / examples / platform mins updated
- [ ] Migration notes for breaking changes
- [ ] Public dartdoc for new/changed APIs
- [ ] Example app still demonstrates key APIs
- [ ] LICENSE / topics / description OK

## Quality

- [ ] `dart format` / `flutter analyze` clean
- [ ] `flutter test` pass
- [ ] Example analyze (if present)
- [ ] `dart pub publish --dry-run` clean

## GitHub feedback

### Beta ship
- [ ] Tracking issue opened/updated (“Beta feedback: …”)
- [ ] How-to-try version pin documented
- [ ] Related issues commented

### Promote
- [ ] Beta published ≥ 7 days ago
- [ ] Issues searched for regressions / beta feedback
- [ ] No critical blockers (or user accepted residual risk)
- [ ] Tracking issue closed/updated after stable publish

### Stable bugfix
- [ ] Fixed issues commented with version
- [ ] Close policy followed

## Publish (needs explicit human approval)

- [ ] User approved `dart pub publish` for exact version
- [ ] Published; pub.dev versions page verified
- [ ] Tag pushed (if used): `v<version>` or repo convention
- [ ] Install constraint shared with user
