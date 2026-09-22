# Dumplings Agent Guide

This file applies to the root repository and its checked-out submodules unless a nearer `AGENTS.md` overrides it. It contains repository-wide constraints. Detailed workflows belong in the component READMEs and `.agents/skills` references rather than being repeated here.

## Start Here

Read the README for the component being changed:

- `README.md` for repository operation and task basics.
- `Core/README.md` for the runner, hooks, workers, dependencies, and synchronization.
- `Modules/PackageModule/README.md` for the task model, manifest model, shared services, and in-process parser APIs.
- `Modules/InstallerParsers/README.md` for the GPL CLI boundary and parser contracts.

Use the matching project skill before doing domain work:

| Work | Skill |
| --- | --- |
| Installer identification, static parsing, parser development, ARP evidence, or VM validation | `.agents/skills/analyze-winget-installer/SKILL.md` |
| WinGet manifest research, authoring, localization, validation, or submission | `.agents/skills/author-winget-manifest/SKILL.md` |
| Dumplings task creation, review, debugging, source selection, or dry runs | `.agents/skills/author-dumplings-task/SKILL.md` |
| Shared networking, file, archive, text, feed, browser, HTML, or YAML APIs | `.agents/skills/use-dumplings-functions/SKILL.md` |

When a new finding changes a domain workflow, update the focused skill reference. Do not copy the same rule into this file.

## Safety And Evidence

- Use PowerShell 7.4 or later. Run repository commands from the Dumplings root unless a command explicitly targets a submodule.
- Never execute an unknown installer or extracted payload on the host. Use static analysis on the host and an appropriate isolated VM or sandbox for dynamic evidence.
- Do not invent metadata, registry values, switches, binary-field meanings, or runtime behavior. Preserve unresolved evidence explicitly and validate only the affected decision.
- Keep secrets and transient state out of Git. `.env`, `Secret.yaml`, `Sandbox`, and `Outputs` are local working data, not durable fixtures or source evidence.
- Preserve unrelated user and automation changes. Do not reset, revert, delete, or broadly reformat files outside the requested work.

## Repository Boundaries

Dumplings is a superproject with independently versioned repositories:

```text
Dumplings                         root project (MIT)
+-- Core                          git submodule (Apache-2.0)
+-- Modules/PackageModule         git submodule (Apache-2.0 with file exceptions)
`-- Modules/InstallerParsers      git submodule (file-specific GPL/MIT)
```

Inspect the root and every affected submodule before editing. Root `git status` reports a modified submodule only as a pointer change, so also run `git -C <submodule> status --short` and review that repository's diff. When commits are requested, commit inside the submodule before updating the root pointer. Do not add yourself as a commit author.

Changes under `Tasks` may be automation output from another session. Do not edit or discard them unless they are part of the request. Avoid repository-wide formatting passes over task scripts.

Respect licensing boundaries. Compatible shared infrastructure may live in PackageModule. GPL parser logic stays in InstallerParsers and crosses into PackageModule through the JSON child-process bridge. Mirrored shared sources in both submodules must remain byte-identical.

## Source And Documentation Style

- Follow `.editorconfig`: UTF-8 without BOM, CRLF, final newline, no trailing whitespace, and two-space indentation for PowerShell, YAML, and JSON.
- Prefer existing helpers and standard-library APIs over local copies. Keep format semantics in the owning installer or service module and reusable mechanics in the focused infrastructure module.
- Prefer deterministic ordered data, typed collections, bounded streams, and direct calls. Avoid accidental `Object[]` materialization and unbounded whole-file reads.
- Add comment-based help to public functions. Document ownership, offset bases, units, limits, and output contracts when they are not obvious. Comment meaningful parsing or failure paths rather than restating assignments.
- Do not use module-wide `$ErrorActionPreference` to force helper failures. Use terminating errors and common `-ErrorAction` behavior where appropriate.
- Guard managed source loading against repeated imports. Tests and worker runspaces may load the same module more than once.
- Keep functions independently callable where practical. A Core-global optimization must retain its documented standalone fallback.
- In `.agents/skills` references, keep each prose paragraph and list item on one physical line. In fenced source examples, do not wrap one command or expression merely to fit a display width.

## Core Integration

Core owns runner infrastructure. PackageModule lifecycle behavior belongs in `Modules/PackageModule/Hooks` rather than hard-coded changes to `Core/Index.ps1`. Cleanup hooks must be idempotent and release resources after success, failure, timeout, or forced worker termination.

Use `Use-Mutex`, `Use-Semaphore`, or `Use-Monitor` from `Core/Libraries/Synchronization.psm1`; task scripts must not construct raw synchronization primitives. Native `winget` calls remain serialized.

`$Global:DumplingsStorage` is synchronized process-wide storage shared by thread-job runspaces. `$Global:DumplingsSessionStorage` is runspace-local. Shared storage does not create task ordering: declare producer dependencies with `DependsOn` in `Config.yaml`.

## Tests And Fixtures

Add focused tests in the repository that owns the implementation. Test behavior and contracts, not documentation prose. When a bridge or shared result contract changes, cover both sides.

Durable external fixtures live under `../Dumplings-TestFixtures`:

```text
Installers/<Family>/<PackageIdentifier>/<Version>  downloaded installer fixtures
Builders/<Family>/...                              controlled builder outputs
Sources/<Family>/...                               source-code references
Research/<Family>/...                              durable manual evidence
```

Synthetic fixtures, extraction trees, decompressed payloads, and temporary inspection output belong in Pester's `$TestDrive`. Do not make tests depend on `Downloads`, `Temp`, `Sandbox`, `Outputs`, or a user's submission-installer directory. Do not commit large installer binaries solely to stabilize a test.

Use the byte-identical `Tests/Support/TestFixture.ps1` helper in both parser submodules. Pester mocks must target the session state that owns the called function; use `-ModuleName` when code under test invokes another module.

Run the narrowest relevant suites, then the affected integration suites. Typical checks are:

```powershell
Invoke-Pester .\Core\Tests
Invoke-Pester .\Modules\PackageModule\Tests
Invoke-Pester .\Modules\InstallerParsers\Tests
Invoke-ScriptAnalyzer .\Path\To\ChangedModule.psm1
git diff --check
git -C Core diff --check
git -C Modules/PackageModule diff --check
git -C Modules/InstallerParsers diff --check
```

Use accepted ScriptAnalyzer exclusions explicitly instead of rewriting intentional best-effort cleanup. Before finishing, report the tests run, skipped fixtures, unavailable real fixtures, and any remaining validation gap.
