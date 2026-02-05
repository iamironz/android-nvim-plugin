# Contributing

Thanks for contributing.

## Requirements

- Neovim 0.9+ with Lua support
- Android SDK tools and `adb` for Android workflows
- Xcode tools for iOS workflows

## Workflow

1. Follow local setup and dev workflow in
   [docs/maintainers/development.md](docs/maintainers/development.md).
1. Run tests before opening a PR:

```bash
./scripts/run-tests.sh
```

1. Update docs for behavior and configuration changes.
1. Update `CHANGELOG.md` for user-visible changes.

## Pull Request Expectations

- Describe behavior changes and reasoning clearly.
- Include reproducible test steps and outcomes.
- Update docs and changelog when required.
- Document any compatibility or migration impact.

## Documentation Writing Standard

Use [docs/maintainers/docs-writing.md](docs/maintainers/docs-writing.md) for structure,
markdown conventions, and explanation style.

## Maintainer Docs

- Development: [docs/maintainers/development.md](docs/maintainers/development.md)
- Release: [docs/maintainers/release.md](docs/maintainers/release.md)
- Triage: [docs/maintainers/triage.md](docs/maintainers/triage.md)
