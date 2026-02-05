# Triage Guide

## Purpose

Define issue intake, labeling, and follow-up policy.

## Intake Flow

1. Confirm issue template quality.
1. Reproduce issue when possible.
1. Apply labels for type, status, and scope.

## Label Set

- `bug`, `enhancement`, `documentation`, `security` for issue type
- `question` for usage questions
- `help wanted` for contributor-needed work
- `good first issue` for newcomer-friendly tasks
- `tests`, `refactor`, `chore` for implementation focus
- `triage/needs-info` for missing logs or repro steps
- `triage/confirmed` for validated issues
- `triage/blocked` for upstream/external blockers
- `triage/duplicate` for duplicates
- `triage/wontfix` for out-of-scope requests

## Follow-Up Policy

- Close `triage/needs-info` after 14 days without response.
- For `triage/blocked`, document blocker and recheck date.
- Close `triage/duplicate` with canonical issue link.
- Close `triage/wontfix` with concise rationale and alternatives when possible.
