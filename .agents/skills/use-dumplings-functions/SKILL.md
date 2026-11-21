---
name: use-dumplings-functions
description: Select and use shared Dumplings PackageModule, Core, PowerHTML, and powershell-yaml functions for networking, redirects, response decoding, temporary files, archive extraction, text and structured data, time conversion, update feeds, Playwright browser access, HTML parsing, and YAML processing. Use alongside installer analysis, WinGet manifest authoring, or Dumplings task authoring whenever commands or scripts need project helper APIs.
---

# Use Dumplings functions

## Execution context

Run these module functions with PowerShell 7.4 or later (`pwsh`). PackageModule and Core do not support Windows PowerShell 5.1.

Core loads PackageModule and the PowerShell modules declared in `Preference.yaml` before it runs task scripts. Do not add `Import-Module` calls to `Tasks/*/Script.ps1`.

In a standalone repository shell, load the required external modules and PackageModule.

```powershell
Import-Module PowerHTML, powershell-yaml -ErrorAction Stop
. .\Modules\PackageModule\Index.ps1
```

Use `Get-Command <Name> -Syntax` to check parameters when an old task example differs from current metadata. Functions may depend on other loaded PackageModule files. Reuse them instead of copying their implementations.

Normal imports reuse implementation modules. During development, reload changed source with `. .\Modules\PackageModule\Index.ps1 -Reload`. Use `Copy-Object` for data copying and `Test-ObjectValueEqual` for structural equality. Copying preserves dates, scriptblocks, explicit nulls, and nested empty arrays. Disposable .NET resources cannot be cloned.

## Function groups

- Read [networking](references/networking.md) for GitHub API calls, URI composition, redirects, headers, response decoding, and embedded JSON.
- Read [files and archives](references/files.md) for cached downloads, temporary paths, and bounded archive extraction.
- Read [content and data](references/content-data.md) for text normalization, HTML text projection, encodings, INI/XML conversion, lists, and time conversion.
- Read [update feeds](references/feeds.md) for Squirrel and electron-builder feed strings already retrieved by the caller.
- Read [browser access](references/browser.md) for scoped Playwright leases and detached browser results.
- Read [external modules](references/external-modules.md) for PowerHTML and powershell-yaml commands.

Read only the groups needed for the current operation. Use `$analyze-winget-installer` for family-specific parser APIs, `$author-winget-manifest` for manifest fields, and `$author-dumplings-task` for task lifecycle and source recipes.

## Usage rules

Reuse shared helpers and follow their ownership and cleanup contracts. Register PackageTask installer downloads in `$this.InstallerFiles`. Standalone callers own temporary resources unless the function states otherwise.

For versionless package sources, prefer PackageTask's `CheckInstallerUpdates`/`CompleteInstallerUpdates` workflow over composing probes, hashes, and publishing branches yourself. Read the [versionless task contract](../author-dumplings-task/references/sources/versionless.md) for validators, per-entry overrides, callback ownership, and legacy-state mappings. These methods register downloads and retain verified hash evidence automatically.

Keep browser leases short and return detached values. Never retain page, locator, response, or browser objects after a scoped helper returns. Never execute a downloaded installer on the host.
