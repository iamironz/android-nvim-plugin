# Release

This guide covers the minimal steps to publish a release.

## Versioning

Use SemVer:

- **Major.** Breaking changes
- **Minor.** New features
- **Patch.** Fixes and docs

## Checklist

- **Update.** `CHANGELOG.md` with the new version and date.
- **Run tests.** `./scripts/run-tests.sh` locally.
- **Verify CI.** Ensure CI is green on the release branch.
- **Verify docs.** README and docs match current behavior.
- **Tag.** Create a tag matching the version, for example `v0.4.0`.

## Publish

1. **Push tag.** Push the tag to the repository.
2. **Create release.** Create a GitHub release using the changelog entry.
3. **Announce.** Announce the release in the README if required.

## Post release

- **Monitor.** Monitor new issues for regressions.
- **Triage.** Triage and label any follow-ups.
