# Release Guide

## Purpose

Define repeatable steps to cut and publish a release.

## Versioning

Use SemVer:

- Major: breaking changes
- Minor: new features
- Patch: fixes and docs

## Pre-Release Checklist

1. Update `CHANGELOG.md` with version and date.
1. Move release-ready notes out of `Unreleased` and leave `Unreleased` ready for the next cycle.
1. Run `./scripts/run-tests.sh` locally.
1. Confirm CI is green.
1. Verify docs match released behavior.
1. Create version tag (for example `v0.6.0`).

## Publish

1. Push release tag.
1. Create GitHub release from changelog entry.
1. Post release note announcement if needed.

## Post-Release

- Monitor issues for regressions.
- Triage and label follow-up reports.
