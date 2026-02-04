# Triage

This guide defines how issues are labeled and progressed.

## Intake

1. Confirm the report matches the bug or feature template.
2. Reproduce the issue when possible.
3. Apply labels to reflect status and scope.

## Labels

- `bug`, `enhancement`, `documentation`, `security` for type.
- `question` for user questions or unclear usage.
- `help wanted` for issues that need contributor help.
- `good first issue` for newcomer friendly tasks.
- `tests`, `refactor`, `chore` for implementation focus.
- `triage/needs-info` when the report lacks logs or steps.
- `triage/confirmed` once reproduced or validated.
- `triage/blocked` when waiting on upstream or external tools.
- `triage/duplicate` for duplicates.
- `triage/wontfix` when out of scope.

## Follow up

- If `triage/needs-info` has no response after 14 days, close with a note.
- For `triage/blocked`, document the blocker and a recheck window.
- Close `triage/duplicate` with a link to the canonical issue.
- Close `triage/wontfix` with a brief explanation and any alternatives.
