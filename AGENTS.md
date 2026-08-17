# clean_k_chart_ai

This is a multi-project workspace, **not** a buildable project. There is no build / test / lint / typecheck / task runner at the root.

## Directory Structure

| Path | Description |
|------|-------------|
| `ai/config/rules/` | Mandatory development standards; MUST read the relevant rule file(s) with your Read tool before writing any code |
| `ai/config/skills/` | On-demand skill library, not auto-loaded; each subdir is a skill — when a task may need one, discover the most suitable subdir and read its SKILL.md `description` to use |
| `ai/output/specs/` | Source-of-truth system behavior specs; read when needed or when requirements are unclear |
| `ai/output/changes/archive/` | Archived change records (proposal/design); read design Decisions & proposal Why for past rationale, or for prior art when scoping a similar change — current behavior specs live in `ai/output/specs/` |
| `ai/output/memories/` | Bad cases & lessons; read when facing blockers or seeking proven experience |
| `modules/` | Independent projects, each its own git repo + guidance file |
| `readonly-dependencies/` | Read-only dependency references; never modify |

## modules

Each project under `modules/` is an independent git repository with its own git remote, toolchain, and `guidance file`.

| Module Name | Path | Guidance File | Description |
|-------------|------|---------------|-------------|
| clean_k_chart | `modules/clean_k_chart` | `modules/clean_k_chart/AGENTS.md + CLAUDE.md` | K-line/candlestick chart package — Flutter/Dart, CustomPainter renderers, MA/EMA/BOLL/MACD/KDJ/RSI indicators |
| clean_k_chart_example | `modules/clean_k_chart_example` | `modules/clean_k_chart_example/AGENTS.md + CLAUDE.md` | Example app for clean_k_chart — Flutter counter template, chart demo not yet wired |

## readonly-dependencies

Stores **read-only references** to private dependencies for local reading. Not part of the build; depended on by modules. When you need to understand the technical frameworks, references, or other knowledge that `modules/<module>` depends on, prioritize reading the relevant content under this directory first; if not found, then traverse other directories or search the web.

| Dependency Name | Path | Description |
|-----------------|------|-------------|
| k_chart_plus | `readonly-dependencies/k_chart_plus` | Flutter K-line/candlestick chart package — Flutter/Dart, indicators MA/EMA/BOLL/MACD/KDJ/RSI |

## rules

CRITICAL: Before writing or modifying code in any module, you MUST use your Read tool to read the full content of the rule file(s) relevant to that module's tech stack. Match by semantic relevance — e.g. a Flutter module → `flutter-development-guidelines.md`; a Java module → `java-development-guidelines.md` + applicable sub-rules under `java/`. These are mandatory standards, not optional references. Non-compliance is a defect that reviewers will flag.

| Rule | Path | Description |
|----------|------|-------------|
| java-development-guidelines | `ai/config/rules/java-development-guidelines.md` | Java development standards — naming/comments/concurrency; architecture sub-rules under `java/` (ms/ddd/bmp/tool) |
| frontend-development-guidelines | `ai/config/rules/frontend-development-guidelines.md` | Frontend development standards — placeholder (content to be filled) |
| flutter-development-guidelines | `ai/config/rules/flutter-development-guidelines.md` | Flutter development standards — placeholder (content to be filled) |

## Workflow

When working under `modules/`, read the standards in the following order:

1. Module guidance file: `modules/<module>/AGENTS.md`
2. **MUST**: Use your Read tool to load the full content of each relevant rule file under `ai/config/rules/` before writing any code. Match by tech stack.

In case of conflict, the module guidance file takes precedence.

## Guardrails

- `readonly-dependencies/` is a read-only knowledge base: writing / modifying / git pushing / deleting files within it is prohibited.
