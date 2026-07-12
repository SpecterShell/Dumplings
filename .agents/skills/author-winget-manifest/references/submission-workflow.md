# Submission Workflow

## Local Validation

Run validation before submission when tools are available:

```powershell
winget validate --manifest <manifest-directory>
```

For local install testing:

```powershell
winget settings --enable LocalManifestFiles
winget install --manifest <manifest-directory>
```

Do not run unknown installers on the host. Use Windows Sandbox, a Hyper-V VM, or the installer-analysis workflow for dynamic install validation.

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
- `Binary-Validation-Error`: installer is flagged, inaccessible, corrupt, or otherwise fails static scan.

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

## Validation And Publishing Lifecycle

After submission, [`wingetbot`](https://github.com/wingetbot) starts the Azure Validation pipeline. Its PR comments contain the pipeline link and validation results, and automation applies labels describing add/remove and validation state.

Do not assume every dynamic-validation failure is caused by the manifest. The validation service has known classes of infrastructure and automation problems tracked by [microsoft/winget-pkgs#325593](https://github.com/microsoft/winget-pkgs/issues/325593). Inspect the pipeline artifacts before changing otherwise-supported manifest fields in response to `Internal-Error-Dynamic-Scan`, unexplained installation failures, or inconsistent bot output.

After merge, the publish pipeline applies the merged manifest changes to the built WinGet source index. A merged YAML change is not visible to clients until publication completes.

## Retrieve Azure Validation Logs

Use the bundled read-only PowerShell script to find the latest `wingetbot` pipeline comment and download both `InstallationVerificationLogs` and `ValidationResult`:

```powershell
.\.agents\skills\author-winget-manifest\scripts\Get-WinGetPRValidationLog.ps1 `
  -PullRequest 123456 `
  -OutputDirectory .\ValidationLogs\123456
```

Anonymous GitHub access works for public PRs but is rate limited. The script uses `$env:GH_DUMPLINGS_TOKEN` by default, matching the other Dumplings GitHub API helpers; supply `-GitHubToken` only to override it. The script never closes, reopens, labels, or comments on a PR.

When the Azure link or build ID is already known:

```powershell
.\.agents\skills\author-winget-manifest\scripts\Get-WinGetPRValidationLog.ps1 `
  -PipelineUrl 'https://dev.azure.com/shine-oss/winget-pkgs/_build/results?buildId=123456' `
  -Force

.\.agents\skills\author-winget-manifest\scripts\Get-WinGetPRValidationLog.ps1 `
  -BuildId 123456 `
  -ArtifactName InstallationVerificationLogs
```

Artifacts are saved as ZIP files and expanded into same-name directories by default. Use `-NoExpand` to keep only archives, `-Force` to replace previous output, or `-WhatIf` to resolve the PR/build/artifact metadata without writing files. Review `InstallationVerificationLogs` for WinGet command output and installer behavior; use `ValidationResult` for structured validation status and exit-code evidence.

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
