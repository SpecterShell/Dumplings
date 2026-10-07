# Submission Workflow

## Local Validation

Load Dumplings and run its offline, process-safe validator before submission:

```powershell
. .\Modules\PackageModule\Index.ps1
$ManifestDirectory = 'C:\Path\To\ManifestDirectory'
Test-WinGetManifest -Path $ManifestDirectory
```

`Get-WinGetManifestValidationResult -Path <manifest-directory>` always returns structured diagnostics, effective installer entries, and dependency evidence. It also accepts `-Manifest` for an in-memory logical manifest. Use `Test-WinGetManifest -Path <manifest-directory> -PassThru` when the same result should be returned only after validation errors have been converted to a terminating error. Add `-ErrorOnWarning` to `Test-WinGetManifest` for the strict warning behavior of `winget validate`. That switch does not belong to `Get-WinGetManifestValidationResult`. Validation does not download or execute installers and does not require `winget.exe`. The winget-pkgs validation service remains authoritative for repository, catalog, security, and installer-content checks.

Before validation, confirm every YAML file uses the exact fixed two-line Dumplings header from [Manifest model and files](../manifest/model-and-files.md#fixed-headers). Its schema family must match `ManifestType`, and every schema URL and `ManifestVersion` in the submitted set must use the repository-recommended version consistently, currently `1.12.0`.

Also check the exact physical names from [File set](../manifest/model-and-files.md#file-set). The version document must be `<PackageIdentifier>.yaml`. A filename such as `<PackageIdentifier>.version.yaml` fails the winget-pkgs manifest-path rules even when the YAML contains `ManifestType: version`.

Check the identifier directory hierarchy at the same time. Split every dot-delimited `PackageIdentifier` component into a separate directory. Do not submit `Google.Chrome.Canary` under `Google.Chrome.Canary` or `Chrome.Canary`. Its hierarchy is `manifests/g/Google/Chrome/Canary/<PackageVersion>/`.

For local install testing:

```powershell
winget settings --enable LocalManifestFiles
winget install --manifest C:\Path\To\ManifestDirectory
```

Do not run unknown installers on the host. Use Windows Sandbox, a Hyper-V VM, or the installer-analysis workflow for dynamic install validation.

## Dumplings Parser Bypass

When an existing package must retain its authored installer metadata without running Dumplings' static parser stage, use the global submission preference:

```powershell
.\Core\Index.ps1 -Name Vendor.Package -Force -EnableSubmit -Dry -SkipInstallerAnalysis
```

For one automation task, set the equivalent model-specific option in `Config.yaml`:

```yaml
SkipInstallerAnalysis: true
```

Either setting skips nested payload extraction, installer-family detection, and static metadata parsers. Installer downloads required for SHA-256, release-date handling, manifest formatting, validation, and submission still run. Use this only when the preserved manifest fields are already supported by other evidence. It does not waive installer analysis or VM validation during manifest authoring.

## Candidate comparison failures

Dumplings retries the final branch comparison before creating a PR. A comparison failure emits a warning and continues submission without the empty-change and exact duplicate checks. A confirmed empty diff still stops submission, and a confirmed identical self-authored PR is preserved. Old PRs are closed only after the replacement PR is created successfully.

## Common Blocking Issues

Check for these before opening or updating a PR:

- `Manifest-Validation-Error`: invalid YAML, missing required fields, wrong schema, singleton manifest, or path mismatch.
- `Error-Hash-Mismatch`: `InstallerSha256` does not match the public `InstallerUrl`.
- `Validation-HTTP-Error`: installer URL uses plain HTTP.
- `Validation-Domain` or `Validation-Unapproved-URL`: URL is not clearly official or not discoverable from the publisher source.
- `Validation-Indirect-URL`: manifest points to an avoidable redirect instead of a direct official URL.
- `Error-Installer-Availability`: installer URL contains expired signed parameters, session-bound query values, or other dynamic data that WinGet cannot replay.
- Unofficial mirror regression: an existing package changes from the publisher's official domain to a personal GitHub mirror, new CDN, or third-party host without publisher cross-link evidence.
- `Validation-Unattended-Failed`: installer does not complete silently with declared type/switches.
- `Manifest-Installer-Validation-Error`: installer type, MSIX metadata, or `AppsAndFeaturesEntries` is inconsistent.
- `PullRequest-Error`: PR includes more than one package version or unrelated files.
- `Binary-Validation-Error`: installer fails static scan. Verify the hash, accessibility, and reported security detection. A blocking ESRP detection cannot be waived by a moderator or administrator. Resolve the detection and obtain a new validation run.

Red `Policy-*`, `Validation-Domain`, and `Validation-Executable-Error` labels require Windows Package Manager administrator review. Community moderator approval cannot waive them. `Internal-Error-*` labels can indicate service failures. Inspect the current checks and artifacts before changing evidence-backed manifest values or requesting a rerun.

## PR Scope

Each PR may contain exactly one of these change shapes:

- Add the manifests for one version of one package.
- Remove the manifests for one version of one package.
- Modify the manifests for one existing version of one package.
- Add one version and remove one version of the same package, such as replacing an incorrect version directory.

Do not combine different package identifiers, unrelated versions, documentation, tooling, spelling fixes, or other repository changes in the same PR.

Every manifest YAML file must be inside a leaf version directory:

```text
manifests\g\Google\Chrome\150.0.7871.115\
```

Do not place YAML files directly in `manifests\g\Google\Chrome\` or another publisher/package directory. The leaf directory must represent the exact `PackageVersion`, and its path must match the package identifier hierarchy.

The no-dot rule applies only to the identifier directories. A version directory such as `150.0.7871.115` keeps its dots because it must match `PackageVersion` exactly.

## Validation And Publishing Lifecycle

After submission, a GitHub App reports validation directly in the PR's **Checks** tab. The production app is `wingetvalidator-prod`. The current stages are PR structure, manifests, URLs, URL domains, manifest policy, catalog content, installer scans, installation, installer metadata, and `10. Validation Completed`. A historical `Azure-Pipeline-Passed` label can still appear. It does not mean that the current logs live in Azure DevOps.

Follow [Validation logs and check results](validation-logs.md) to download the current operation's artifacts. Record each relevant check's status and conclusion, not just the completion check or labels. The catalog stage also checks ARP version-range overlaps, declared dependency availability and minimum versions, and removal safety. Local schema validation cannot reproduce the live catalog.

Installation validation starts as a standard, non-elevated user. Reproduce the exact switches and elevation route in the [VM workflow](../../../analyze-winget-installer/references/workflows/vm-validation.md). Set `ElevationRequirement: elevationRequired` only when that route requires explicit pre-elevation. Machine scope or a writable `Program Files` target alone does not prove it, and package updates must not add it automatically.

When feedback is required, the current repository policy adds `No-Recent-Activity` after five days and closes the PR after three more days without activity. For eligible PRs, ask at most two active moderators and avoid pinging community moderators for administrator-only labels. Moderators can request a fresh validation with `@wingetbot run`. Agents should not comment or trigger reruns without user authorization. See [Moderation](https://github.com/microsoft/winget-pkgs/blob/master/doc/Moderation.md) and the [failure guide](https://github.com/microsoft/winget-pkgs/blob/master/doc/ValidationFailureGuide.md).

After merge, the publishing service applies the merged manifest changes to the WinGet source index. Check the publishing comment and labels before expecting clients to see the version. Merge alone does not establish publication.

## Evidence To Report

When presenting a completed manifest update, report:

- Package identifier and version.
- Source type: homepage, support page, GitHub release, or other official source.
- Installer URLs, architectures, redirect-chain decision, and query-parameter stability check.
- Installer type and how it was detected.
- ARP/version evidence and any `AppsAndFeaturesEntries` choices.
- Release-note source selection, removed unrelated sections, conversion pipeline, and final `ReleaseNotesUrl`.
- Validation commands run and results.
- Any unresolved risks, such as official vanity URLs, dynamic signed URLs, blocked downloads, missing release notes, archived GitHub repositories, or suspicious source changes.

## Primary references

- [winget-pkgs authoring](https://github.com/microsoft/winget-pkgs/blob/master/doc/Authoring.md)
- [winget-pkgs policies](https://github.com/microsoft/winget-pkgs/blob/master/doc/Policies.md)
- [winget-pkgs validation stages](https://github.com/microsoft/winget-pkgs/blob/master/doc/Validation.md)
- [winget-pkgs validation failure guide](https://github.com/microsoft/winget-pkgs/blob/master/doc/ValidationFailureGuide.md)
- [WinGet manifest schema documentation](https://github.com/microsoft/winget-pkgs/tree/master/doc/manifest/schema/1.12.0)
