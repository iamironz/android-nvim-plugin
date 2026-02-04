# Release

This guide covers the minimal steps to publish a release.

## Versioning

Use SemVer:

- Major: breaking changes
- Minor: new features
- Patch: fixes and docs

## Checklist

- Update `CHANGELOG.md` with the new version and date.
- Run `./scripts/run-tests.sh` locally.
- Ensure CI is green on the release branch.
- Verify README and docs match current behavior.
- Create a tag matching the version, for example `v0.4.0`.

## Publish

1. Push the tag to the repository.
2. Create a GitHub release using the changelog entry.
3. Announce the release in the README if required.

## Post release

- Monitor new issues for regressions.
- Triage and label any follow-ups.
