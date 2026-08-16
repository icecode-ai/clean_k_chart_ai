# clean_k_chart_ai

This is a multi-project workspace, **not** a buildable project. There is no build / test / lint / typecheck / task runner at the root.

## Directory Structure

| Path | Description |
|------|-------------|
| `ai/config/rules/` | Rules & standards; apply when relevant |
| `ai/config/skills/` | On-demand skills; invoke only when the user explicitly requests |
| `ai/output/specs/` | Source-of-truth system behavior specs; read when needed or when requirements are unclear |
| `ai/output/changes/archive/` | Archived change records (proposal/design); read design Decisions & proposal Why for past rationale, or for prior art when scoping a similar change — current behavior specs live in `ai/output/specs/` |
| `ai/output/memories/` | Bad cases & lessons; read when facing blockers or seeking proven experience |
| `modules/` | Independent projects, each its own git repo + guidance file |
| `readonly-dependencies/` | Read-only dependency references; never modify |

## modules

Each project under `modules/` is an independent git repository with its own git remote, toolchain, and `guidance file`.

| Module Name | Path | Guidance File | Description |
|-------------|------|---------------|-------------|
| clean_k_chart | `modules/clean_k_chart` | `modules/clean_k_chart/AGENTS.md` | K-chart package — Flutter/Dart, early stage |
| clean_k_chart_example | `modules/clean_k_chart_example` | `modules/clean_k_chart_example/AGENTS.md` | Example app for clean_k_chart — empty repo, no code/toolchain yet |

## readonly-dependencies

Stores **read-only references** to private dependencies for local reading. Not part of the build; depended on by modules.

| Dependency Name | Path | Description |
|-----------------|------|-------------|
| k_chart_plus | `readonly-dependencies/k_chart_plus` | Flutter K-line/candlestick chart package — Flutter/Dart, indicators MA/EMA/BOLL/MACD/KDJ/RSI |

## rules

Rules & standards, apply when relevant.

| Rule | Path | Description |
|----------|------|-------------|
| java-development-guidelines | `ai/config/rules/java-development-guidelines.md` | Java development standards — entry pointing to java/a-java-common-guidelines.md |
| frontend-development-guidelines | `ai/config/rules/frontend-development-guidelines.md` | Frontend development standards — entry pointing to frontend/a-frontend-common-guidelines.md |
| flutter-development-guidelines | `ai/config/rules/flutter-development-guidelines.md` | Flutter development standards — entry pointing to flutter/a-flutter-common-guidelines.md |
| a-java-common-guidelines | `ai/config/rules/java/a-java-common-guidelines.md` | Java common guidelines — placeholder (content to be filled) |
| a-frontend-common-guidelines | `ai/config/rules/frontend/a-frontend-common-guidelines.md` | Frontend common guidelines — placeholder (content to be filled) |
| a-flutter-common-guidelines | `ai/config/rules/flutter/a-flutter-common-guidelines.md` | Flutter common guidelines — placeholder (content to be filled) |

## Workflow

When working under `modules/`, read the standards in the following order:

1. Module guidance file: `modules/<module>/AGENTS.md`
2. Rules under `ai/config/rules/` relevant to the module's tech stack, if any

In case of conflict, the module guidance file takes precedence.

## Guardrails

- `readonly-dependencies/` is a read-only knowledge base: writing / modifying / git pushing / deleting files within it is prohibited.
