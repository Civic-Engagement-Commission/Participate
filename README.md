# decidim-nyc

A Decidim instance for New York City participatory democracy initiatives, maintained by [openpoke](https://github.com/openpoke).

Based on the [Decidim](https://github.com/decidim/decidim) framework. Decidim and this distribution are licensed under [AGPLv3](./LICENSE-AGPLv3.txt).

## Decidim version

Currently running **Decidim v0.29.1**.

### Installed modules

Sourced from `Gemfile`:

| Module                          | Source                                                                                          |
|---------------------------------|-------------------------------------------------------------------------------------------------|
| Official Decidim modules        | `decidim/decidim` @ `v0.29.1` (accountability, admin, api, assemblies, blogs, budgets, comments, core, debates, forms, meetings, pages, participatory_processes, proposals, surveys, system, verifications) |
| `decidim-decidim_awesome`       | OpenSourcePolitics fork (temporary — see `.claude/tasks/phase-1.5-internal-gems-migration.md`)  |
| `decidim-term_customizer`       | OpenSourcePolitics fork (temporary — see `.claude/tasks/phase-1.5-internal-gems-migration.md`)  |

## Getting started

Local development with Docker: see [docs/DOCKER.md](./docs/DOCKER.md).

## Security

Please report security issues responsibly by emailing the maintainers rather than opening a public issue.

## License

AGPLv3. See [LICENSE-AGPLv3.txt](./LICENSE-AGPLv3.txt).

This work is a derivative of [Decidim](https://github.com/decidim/decidim) (AGPLv3) and includes patches over the upstream framework. Modifications relative to upstream are tracked through this repository's git history.
