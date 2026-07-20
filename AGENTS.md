# Dumplings Agent Guide

This file applies to the root repository and its checked-out submodules unless a
more specific `AGENTS.md` is added below a directory. It is an operating contract
for coding agents, not a replacement for the component READMEs or the workflows
under `.agents/skills`.

## Non-Negotiable Rules

- Use Windows PowerShell Core 7.4 or later. Run repository commands from the
  Dumplings root unless a command explicitly targets a submodule.
- Never execute an unknown or downloaded installer on the host. Analyze it
  statically. Use a checkpointed Windows Sandbox or Hyper-V VM when dynamic
  evidence is unavoidable.
- Never invent package metadata, legal names, registry values, silent switches,
  or installer behavior. Return unresolved evidence as a warning and validate it
  in the VM when necessary.
- Preserve unrelated user changes. Inspect the root and every affected submodule
  before editing; do not reset, revert, or reformat unrelated files.
- Keep secrets out of Git. `.env`, `Secret.yaml`, `Sandbox`, and `Outputs` are
  local state. Do not cite them as durable test fixtures or source evidence.

## Repository And Git Boundaries

Dumplings is a superproject with independently versioned repositories:

```text
Dumplings                         root project (MIT)
+-- Core                          git submodule (Apache-2.0)
+-- Modules/PackageModule         git submodule (Apache-2.0 with file exceptions)
`-- Modules/InstallerParsers      git submodule (file-specific GPL/MIT)
```

`git status` at the root reports a modified submodule only as a pointer change.
When touching a submodule, also run `git -C <submodule> status --short` and review
its own diff. Commit submodule changes in that repository before updating the
root pointer when the user requests commits.

Task state changes under `Tasks` are automation output and may be intentional.
Do not edit or discard them unless the task explicitly requires it. Avoid broad
formatting passes over thousands of task scripts.

## Start With The Existing Architecture

Read the nearest component README before changing its code:

- `README.md`: project operation and task basics.
- `Core/README.md`: runner, dependencies, hooks, workers, and synchronization.
- `Modules/PackageModule/README.md`: task model, manifest model, services, and
  in-process parser APIs.
- `Modules/InstallerParsers/README.md`: GPL CLI boundary and parser contracts.

Use the detailed skills for domain work:

- `.agents/skills/analyze-winget-installer/SKILL.md` for installer analysis,
  parser routing, ARP evidence, and VM validation.
- `.agents/skills/author-winget-manifest/SKILL.md` for source discovery,
  manifest and locale authoring, formatting, validation, and submission.

Do not duplicate their installer-family or manifest-field rules in general
documentation. Update the focused workflow when a newly learned rule affects
future authoring.

## PowerShell And Source Style

- Follow `.editorconfig`: UTF-8 without BOM, CRLF, final newline, no trailing
  whitespace, and two-space indentation for PowerShell, YAML, and JSON.
- Prefer `[ordered]` dictionaries where deterministic serialization matters.
- Add comment-based help to public functions. Document parameters, stream
  ownership, offset bases, units, and output contracts when they are not obvious.
- Comment meaningful parsing and failure paths, not individual assignments.
- Avoid introducing local copies of helpers already provided by `General.psm1`,
  shared binary/archive/PE infrastructure, or Core synchronization.
- Do not set module-wide `$ErrorActionPreference` merely to force helper errors.
  Use advanced functions, terminating errors where required, and common
  `-ErrorAction` behavior.
- Guard `Add-Type` by checking whether its type already exists. Modules are loaded
  repeatedly in tests and worker runspaces.
- Prefer typed lists, streaming output, and bounded streams for large data. Avoid
  accidental PowerShell `Object[]` materialization and unbounded `ReadAllBytes`
  on installer files.
- Keep functions deterministic and independently callable where practical. Core
  globals may be used only where the documented standalone fallback exists.

## Core, Hooks, And Concurrency

Core owns runner infrastructure. PackageModule behavior should normally be wired
through scripts under `Modules/PackageModule/Hooks`, not hard-coded into
`Core/Index.ps1`.

Available lifecycle phases include `RunnerStarting`, `WorkerStarting`,
`BeforeTask`, `AfterTask`, `WorkerStopping`, `BeforeForcedWorkerStop`, and
`RunnerStopping`. Cleanup hooks must be idempotent and release resources even
after task failures or worker timeouts.

Use `Use-Mutex`, `Use-Semaphore`, or `Use-Monitor` from
`Core/Libraries/Synchronization.psm1`. Do not construct raw synchronization
primitives in task scripts. Native `winget` calls must remain serialized because
concurrent invocations can crash the client.

`$Global:DumplingsStorage` is synchronized process-wide storage shared across
thread-job runspaces. `$Global:DumplingsSessionStorage` is runspace-local. If one
task supplies shared data to another, declare it with `DependsOn` in
`Config.yaml`; shared-storage access is not an implicit dependency.

## Package Tasks

A task is selected only when its directory contains `Config.yaml`. Prefer a
nearby, current task from the same publisher as a template, but verify every
assumption. Use `winget search` to find package identifiers before recursively
searching a full `winget-pkgs` checkout.

Declare shared providers explicitly:

```yaml
Type: PackageTask
WinGetIdentifier: Vendor.Package
Skip: false
DependsOn:
- '#Vendor'
```

Let `PackageTask` own state comparison and submission status. Task scripts should
populate `CurrentState`, call `Check()`, and react to its result; do not recreate
model logic locally. Prefer model-side installer downloading and metadata updates
over task-side `Read-ProductCodeFrom*` or manual extraction loops.

Use module feed converters on already-retrieved strings. Network access may need
task-specific headers, cookies, or request parameters, so installer-family
modules must not fetch Squirrel `RELEASES` or electron-updater YAML themselves.

Safe task exercises are:

```powershell
# Read-only release check.
.\Core\Index.ps1 -Name Vendor.Package

# Exercise manifest generation without opening a pull request.
.\Core\Index.ps1 -Name Vendor.Package -Force -EnableSubmit -Dry
```

Do not enable writes, messages, or real submission unless they are explicitly
part of the request.

## Installer Parser Work

Detection is content-first. Use magic bytes, PE resources, CFB CLSIDs, archive
records, and structured manifests; filename extensions and analyzer labels are
secondary evidence. An invalid extension must not change the detected format.

Prefer one `Get-<Family>Info` call and reuse its result. Do not parse the same
installer repeatedly with individual `Read-*From<Family>` helpers. Metadata must
come from explicit structures or registry writes, not arbitrary version/product
string probing.

Parser implementation rules:

- Open an installer once per operation and pass parsed layouts or bounded streams.
- Validate offsets, lengths, counts, alignment, checksums, decompressed sizes,
  destination paths, and recursion depth before allocating or extracting.
- Preserve caller-owned stream position and never dispose caller-owned streams.
- Put reusable mechanics in the shared runtime/binary/compression/archive/PE
  modules; keep installer-format semantics in the focused parser.
- Do not depend on `7z.exe`, NanaZip, `isx.exe`, builder executables, Python
  extractors, or installer execution at runtime.
- Distinguish an outer wrapper from the nested payload that owns the visible ARP
  entry and silent switches.
- Return conditional or incomplete evidence as structured warnings. Never assign
  guessed semantics to unknown proprietary fields.
- Keep parser limits and watchdogs on every malformed-input path.

PackageModule may contain Apache-2.0/MIT-compatible implementations. GPL parser
logic belongs in `Modules/InstallerParsers` and crosses into PackageModule only
through the JSON child-process bridge. Do not import GPL code into PackageModule.
The shared MIT infrastructure in both submodules must remain byte-identical when
either copy changes.

Every full parser should have a source header, format references, comment-based
help, and a compact binary-structure diagram showing the actual headers, offsets,
records, compression boundaries, and nested containers it consumes. Preserve
third-party notices and file-level license headers.

## WinGet Manifest Work

Use the logical manifest pipeline instead of combining YAML dictionaries by hand:

1. `Read-WinGetManifest` or `ConvertFrom-WinGetManifestYaml` parses documents.
2. Model/update functions operate on effective authored installer values.
3. `ConvertTo-WinGetManifestDocumentSet` or `ConvertTo-WinGetManifestYaml`
   serializes multi-file output.
4. `Format-WinGetManifest` only normalizes legal field levels and ordering; it
   must not fabricate, add, or delete evidence fields.
5. `Get-WinGetManifestValidationResult` or `Test-WinGetManifest` validates the
   result offline.

Dictionary atoms inherit recursively from root to installer entries; arrays are
atomic and do not merge. Installer-level values have priority. Serialization
recomputes compact root defaults, so do not manually shuttle fields between root
and installer levels.

For known WinGet installer types, omit switches, modes, and return-code entries
that exactly match WinGet defaults. For example, do not add NSIS `/S` merely to
make the manifest explicit. Preserve manifest-author intent for fields that the
update pipeline intentionally does not infer safely, including package locale
identity, scope, protocols, file extensions, and dependencies.

Current authoring uses schema `1.12.0` with the fixed Dumplings header and a
manifest-type-specific schema comment. Do not author `UnsupportedOSArchitectures`
at present. Follow the authoring skill for all field-level and locale rules.

## Downloads, Browsers, And Messages

Use the WinGet download helpers for installer compatibility checks and downloads;
they implement Delivery Optimization and WinINet behavior, progress, retries,
timeouts, rate-limit bounds, and cleanup. Do not rebuild their fallback logic in
`WinGetManifestUpdate` or task scripts.

Browser automation is a leased process-wide resource:

- Prefer `Use-EdgeDriver` for Selenium and `Use-PlaywrightPage` or
  `Invoke-PlaywrightFetch` for Playwright/Patchright.
- Keep the scoped block as short as possible and return detached strings, URLs,
  HTML, or dictionaries. Never retain `IWebElement`, locator, page, or browser
  objects after the lease ends.
- Do not use unmanaged `New-*Driver` factories under `Tasks`, dispose the shared
  browser directly, or assume headless and visible sessions can coexist.
- `-SolveCloudflare` is best-effort ordinary browser interaction, not a token
  forge or guarantee. Use it only with the Patchright stealth profile.

Telegram and Matrix task notifications should use the process-wide queued APIs.
State messages coalesce by package identifier; queue workers own mutable message
sessions. Do not bypass queue throttling from package tasks.

## Testing And Fixtures

Add focused tests in the repository that owns the implementation. Keep installer
families in separate Pester files rather than growing generic catch-all suites.
Use generated fixtures for structural edge cases and at least three meaningfully
different real installers when format behavior could vary.

Downloaded test installers live under the persistent sibling cache
`../Dumplings-TestFixtures`, managed by each submodule's `Tests/TestFixture.ps1`.
Do not depend on `Downloads`, `Temp`, `Sandbox`, or a user's submission-installer
directory. Never commit large installer binaries merely to stabilize a test.

Minimum targeted verification:

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

Run only the suites relevant to a small change, but add bridge tests whenever a
GPL CLI action or result contract changes. Ignore accepted empty-catch warnings
through `Invoke-ScriptAnalyzer -ExcludeRule` rather than rewriting intentional
best-effort cleanup. Do not add tests whose sole purpose is policing Markdown or
skill prose.

Report which tests ran, which were skipped, and whether any real-fixture test was
unavailable. A parser change is incomplete if it passes synthetic fixtures but
was not checked against the distinct real layouts named by the request.
