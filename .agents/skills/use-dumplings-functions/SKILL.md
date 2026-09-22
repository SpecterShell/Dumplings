---
name: use-dumplings-functions
description: Select and use shared Dumplings PackageModule, Core, PowerHTML, and powershell-yaml functions for networking, redirects, response decoding, temporary files, archive extraction, text and structured data, time conversion, update feeds, Playwright browser access, HTML parsing, and YAML processing. Use alongside installer analysis, WinGet manifest authoring, or Dumplings task authoring whenever commands or scripts need project helper APIs.
---

# Use Dumplings functions

## Execution context

Run these module functions with PowerShell 7.4 or later (`pwsh`). PackageModule and Core do not support Windows PowerShell 5.1.

Core loads PackageModule and the PowerShell modules declared in `Preference.yaml` before it runs task scripts. Do not add `Import-Module` calls to `Tasks/*/Script.ps1`.

For an independent repository shell, load the external modules and PackageModule before using the references:

```powershell
Import-Module PowerHTML, powershell-yaml -ErrorAction Stop
. .\Modules\PackageModule\Index.ps1
```

Use `Get-Command <Name> -Syntax` when current command metadata differs from an old task example. Functions may call helpers from other loaded PackageModule files; do not copy their implementations into task scripts or agent commands.

Normal imports reuse implementation modules. Use `. .\Modules\PackageModule\Index.ps1 -Reload` only when intentionally reloading changed source in a development shell. Use `Copy-Object` and `Test-ObjectValueEqual` for shared data copying and structural equality; the former WinGet-specific copies of these functions were removed. Copying preserves dates, scriptblocks, explicit nulls and nested empty arrays; it does not clone disposable .NET resources.

## Function groups

- Read [networking](references/networking.md) for GitHub API calls, URI composition, redirects, headers, response decoding, and embedded JSON.
- Read [files and archives](references/files.md) for cached downloads, temporary paths, and bounded archive extraction.
- Read [content and data](references/content-data.md) for text normalization, HTML text projection, encodings, INI/XML conversion, lists, and time conversion.
- Read [update feeds](references/feeds.md) for Squirrel and electron-builder feed strings already retrieved by the caller.
- Read [browser access](references/browser.md) for scoped Playwright leases and detached browser results.
- Read [external modules](references/external-modules.md) for PowerHTML and powershell-yaml commands.

Read only the groups required by the current operation. Installer-family parser APIs remain in `$analyze-winget-installer`; manifest field rules remain in `$author-winget-manifest`; task lifecycle and source recipes remain in `$author-dumplings-task`.

## Usage rules

Prefer these shared functions over local download, redirect, encoding, temporary-file, archive, HTML, YAML, feed, or browser implementations. Preserve each helper's ownership and cleanup contract. When a PackageTask downloads an installer explicitly, register the path in `$this.InstallerFiles`; independent callers own their temporary resources unless the function states otherwise.

For versionless package sources, prefer PackageTask's `CheckInstallerUpdates`/`CompleteInstallerUpdates` workflow over composing probes, hashes, and publishing branches yourself. Read the [versionless task contract](../author-dumplings-task/references/sources/versionless.md) for validators, per-entry overrides, callback ownership, and legacy-state mappings. These methods register downloads and retain verified hash evidence automatically.

Keep browser leases short and return detached values. Never retain page, locator, response, or browser objects after a scoped helper returns. Never execute a downloaded installer on the host.
