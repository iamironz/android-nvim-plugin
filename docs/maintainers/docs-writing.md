# Docs Writing Standard

## Purpose

Define consistent structure, markdown style, and explanation patterns for project docs.

## Core Principles

- Lead with user outcome, then steps, then edge cases.
- One page should have one clear intent.
- Prefer short concrete statements over broad prose.
- Use stable terms (`AndroidMenu`, `Build Variants`, `run.config_path`) consistently.

## Page Type Templates

### Start Pages

Use sections in this order:

1. `Purpose`
1. `Prerequisites`
1. `Setup` or `Steps`
1. `Validate` (how to confirm success)
1. `Next steps`

### Guides

Use sections in this order:

1. `Purpose`
1. `Default behavior` or `Mental model`
1. `Controls` or `Entry points`
1. `Recommended flow`
1. `Related docs`

### Reference Pages

Use sections in this order:

1. `Scope`
1. `Definitions/Tables`
1. `Examples`
1. `Related docs`

### Troubleshooting Pages

Use sections in this order:

1. `How to use this page`
1. `Baseline checks`
1. Symptom blocks (`Quick checks`, `Fix`)
1. `Related docs`

## Markdown Conventions

- Keep headings concise and in Title Case.
- Use numbered lists (`1.` style) for procedures.
- Use tables for command/keymap/item inventories.
- Wrap commands, paths, options, and key names in backticks.
- Prefer fenced code blocks with language identifiers.
- End pages with a `Related Docs` section.

## Explanation Pattern

Use this order for each important concept:

1. What it is
1. Why it matters
1. How to use it
1. How to validate it
1. Where to go next

## Link and Move Policy

- Keep canonical pages in the new docs structure.
- Keep legacy path pages as redirects while external links still depend on them.
- Update `docs/README.md` whenever docs paths or ownership change.
