# Contributing

WalkSpeed follows two public conventions:

- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) for commit messages
- [Conventional Branch 1.1.0](https://conventionalbranch.org/) for branch names

The hooks in `.githooks/` check both. Turn them on once per clone:

```sh
git config core.hooksPath .githooks
```

## Branches

`main` is the trunk and must always build. Work happens on short-lived
branches cut from `main`. They are merged back with `git merge --no-ff`, so
each branch stays visible in the history.

Branch names use the format `<type>/<description>`:

| Prefix     | Use it for                                        | Example                      |
| ---------- | ------------------------------------------------- | ---------------------------- |
| `feature/` | New functionality                                 | `feature/speed-alert-engine` |
| `bugfix/`  | Fixes that can wait for the normal flow           | `bugfix/gps-speed-spikes`    |
| `hotfix/`  | Urgent fixes                                      | `hotfix/crash-on-launch`     |
| `release/` | Preparing a release                               | `release/v1.0.0`             |
| `chore/`   | Non-code work such as tooling, docs, dependencies | `chore/update-readme`        |

The spec also allows the aliases `feat/` and `fix/`. This repo uses the long
forms so names stay consistent.

Naming rules:

- Use only lowercase `a-z`, digits `0-9` and hyphens between words.
- Dots are allowed only for version numbers, as in `release/v1.2.0`.
- Never lead, trail or double up hyphens or dots.
- Include the ticket number when there is one, for example
  `feature/issue-12-pace-mode`.

## Commits

```text
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

- **Types:** `feat` adds a feature and bumps MINOR. `fix` fixes a bug and
  bumps PATCH. Other types allowed: `build`, `chore`, `ci`, `docs`, `perf`,
  `refactor`, `revert`, `style`, `test`.
- **Scopes:** a noun naming the part of the code that changed. This repo uses
  `core`, `location`, `audio`, `monitor`, `ui`, `settings` and `release`.
- **Description:** imperative mood, lowercase, no trailing period. Keep the
  header to 72 characters or fewer.
- **Body:** optional. Put one blank line after the header, then explain *why*
  the change was made.
- **Footers:** optional. Put one blank line after the body and write each one
  as `Token: value`, for example `Refs: #12`.
- **Breaking changes:** put `!` before the colon, add a `BREAKING CHANGE:`
  footer, or do both. Either one bumps MAJOR.
- **One logical change per commit.** If a change fits more than one type,
  split it into several commits.

## Releases

Versions follow [SemVer](https://semver.org/). The commits since the last tag
decide the next version. To release:

1. Cut `release/vX.Y.Z` from `main`.
2. Update `CHANGELOG.md` and `MARKETING_VERSION`.
3. Merge the branch into `main`.
4. Tag the merge commit `vX.Y.Z`.
