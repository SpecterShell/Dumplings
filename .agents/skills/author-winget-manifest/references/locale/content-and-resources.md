# Locale content and resources

## License And Copyright

### License

- For an open-source package with a valid SPDX license, use its [SPDX license identifier](https://spdx.org/licenses/), such as `MIT`, `Apache-2.0`, or `GPL-3.0-only`. Verify that the repository or distributed source actually contains the full license text that grants permission, whether in a license file, complete source-file headers, or another complete license section. Search the SPDX list when the identifier is unfamiliar.
- Use `Freeware` for a non-open-source package that is explicitly free to use and is not shareware.
- Use `Proprietary` when the package uses a proprietary license and should not be classified as freeware, or when no more specific public classification is available.
- Do not treat a copyright notice, source-available statement, public repository, license badge, package metadata value, or a README sentence that merely names a license as the license grant. If the project claims an open-source license but provides no license text, do not write that SPDX identifier. Use `Freeware` when the publisher still clearly distributes the application for free, as with [`makise2060/dsh-agent`](https://github.com/makise2060/dsh-agent); otherwise use `Proprietary` until authoritative terms are available.

### LicenseUrl

- For an open-source repository, link to the rendered license file on the repository's default branch using a stable branch alias such as `HEAD`, for example `https://github.com/CherryHQ/cherry-studio/blob/HEAD/LICENSE`.
- Do not use a README license badge, heading, or one-line license claim as `LicenseUrl` when the linked page does not contain the license text. Omit `LicenseUrl` unless another official page provides the applicable terms.
- For proprietary or freeware applications, use the official license agreement, terms of service, or end-user license page.
- The site footer, login page, and installer wizard are useful discovery locations. A URL written to the manifest must remain publicly accessible without running the installer.

### Copyright

Use the package's copyright statement from the application About page or window, the official site footer, or the PE `LegalCopyright` version-resource field. Preserve the published wording and year range.

### CopyrightUrl

- Omit `CopyrightUrl` when `License` is an open-source license and `LicenseUrl` already points to that license.
- Consider it for an open-source package only when the official package or publisher site provides separate terms of service, an additional license, or another legal document beyond the open-source license.
- Add it only when the separate document both governs rights beyond `LicenseUrl` and contains copyright or intellectual-property terms asserted by the publisher.
- Do not use a DMCA notice, takedown policy, infringement-reporting page, or other page that merely discusses third-party copyright enforcement.
- Do not duplicate `LicenseUrl`. Omit `CopyrightUrl` when no qualifying public publisher document exists.

## Descriptions And Discovery

### ShortDescription

Write a concise, neutral explanation of what the package does. Do not use descriptions such as "installer for PackageName" and do not invent capabilities unsupported by official evidence.

### Description

Use a longer official product description when it adds useful detail beyond `ShortDescription`. It may be lightly rewritten for neutrality and clarity without changing factual claims.

### Moniker

Do not add `Moniker` automatically for a new package, even when the product name, executable, command, or package identifier suggests an obvious alias. Keep the field only in the default-locale manifest when the task explicitly requires a short, distinctive, commonly recognized moniker. Preserve an existing package's established moniker during routine updates unless evidence shows that it is incorrect.

### Tags

- Use short, relevant, lower-case search terms.
- Separate words within one multiword tag with hyphens, not spaces or underscores.
- Do not hyphenate a term merely to combine unrelated keywords.
- Use existing winget-pkgs manifests as style examples, but verify that every retained tag describes the current package.
- Avoid publisher names, generic terms such as `software`, and speculative capabilities that do not improve discovery.
- Describe user-facing purpose, workflows, formats, or capabilities rather than implementation details. Do not add a programming language or application framework merely because the application was built with it; omit tags such as `electron`, `tauri`, and `rust` in that case. A language or framework is appropriate only when supporting or developing for it is itself a package feature.
- Omit generic application-form tags such as `desktop`, `cli`, and `command-line`.
- In an additional locale manifest, translate tags that have natural, useful localized search terms.
- If no tags are translatable, omit `Tags` from the additional locale manifest and inherit the default-locale array instead of copying it unchanged.
- If only some tags are translatable, supply the complete intended localized array because `Tags` arrays do not merge. Keep invariant technical terms and replace only the terms that have useful translations.
- Sort and deduplicate `Tags` deterministically with the `en-US` culture in every default and additional locale manifest.

When running PowerShell Core, use:

```powershell
$Tags | Sort-Object -Culture en-US -Unique
```

Do not use this command under Windows PowerShell 5 because its `-Culture` behavior is not reliable for this workflow. Run the sorting step with PowerShell Core instead.

## Agreements And Documentation

### Agreements

Add `Agreements` only when unattended installation requires explicit license acceptance through installer arguments, such as `ACCEPT_EULA=1` for `Microsoft.PowerBI`.

- `AgreementLabel`: a concise name for the agreement.
- `AgreementUrl`: the official public agreement URL.

Do not add an agreement merely because every application has a license or terms of service. Keep installer acceptance switches in the installer manifest as well.

### Documentations

Use `Documentations` for useful official manuals, getting-started guides, administration guides, or troubleshooting pages:

- `DocumentLabel`: the user-facing label. Use a concise name based on the document page title, document URL and the link text to the document, for example "Documentation", "Docs", "User Guide", "Guide", "Tutorial" and "Wiki".
- `DocumentUrl`: the official documentation URL.
- For a package hosted in a GitHub repository, check whether the repository has an enabled, populated Wiki and add that official Wiki when it provides useful package documentation.
- Do not duplicate `PackageUrl`, `PublisherSupportUrl`, or unrelated marketing pages. The support or contact-us page should be used in `PublisherSupportUrl` instead of `Documentations`.
- In an additional locale manifest, include `Documentations` only when at least one `DocumentLabel` has a useful translation. Translate the labels and supply the complete intended array, including each corresponding URL.
- If the labels are proper names, technical identifiers, or otherwise not translatable, omit `Documentations` from the additional locale manifest and inherit the default-locale array.

## Release And Installation Information

### ReleaseNotes

Use the version-specific desktop release-note source selected in [release evidence](../package/release-evidence.md). Do not summarize, paraphrase, or rewrite it. Scrape the raw HTML or Markdown, remove only unrelated material such as download links, asset tables, checksums, mobile-only changes, or platform updates, then preserve the remaining processed text verbatim.

For raw HTML:

```powershell
$ReleaseNotesHtml = Invoke-WebRequest -Uri $ReleaseNotesSourceUrl | Read-ResponseContent
$ReleaseNotes = $ReleaseNotesHtml | ConvertFrom-Html | Get-TextContent | Format-Text
```

For raw Markdown files such as `CHANGELOG.md`, `RELEASES.md`, or `CHANGES.md`:

```powershell
$ReleaseNotesMarkdown = Invoke-RestMethod -Uri $RawReleaseNotesUrl
$ReleaseNotes = $ReleaseNotesMarkdown | Convert-MarkdownToHtml | Get-TextContent | Format-Text
```

GitHub release bodies and other Markdown sources that treat each single newline as a visual line break require `hardlinebreak`:

```powershell
$ReleaseNotes = $Release.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
```

Filter irrelevant sections from the raw source before the conversion pipeline when possible. If filtering the parsed HTML is safer, select only the release-note nodes before `Get-TextContent`. Do not reconstruct the remaining content in different words. The output of `Format-Text` is the manifest text.

If the exact release body has no substantive desktop changes, fall back to the matching version section in a repository-root release-history file, then to the official desktop product's release-notes page. Omit `ReleaseNotes` when no reliable version-specific desktop text exists.

### ReleaseNotesUrl

Use the human-readable official page that supports the selected text. Prefer the exact Git-platform release page when its body contains valid desktop release notes. When text came from a repository release-history file, use its rendered file page with a version anchor when available. Otherwise use the versioned desktop release-history page on the official site.

Do not use a release URL whose body is empty or unrelated merely because the installer asset is attached there. In that case, point to the fallback changelog or official desktop release-notes page. Do not use raw-content URLs as `ReleaseNotesUrl` when a rendered page is available.

### PurchaseUrl

Use the official purchase, subscription, pricing, or entitlement page. Omit it for packages that have no purchasing flow. Do not use the donatation page as `PurchaseUrl`.

### InstallationNotes

Use only for information the user needs after installation, such as a required first-run action or configuration step. Do not repeat installer switches or generic success messages.

## Icons

Do not author `Icons` for winget-pkgs manifests in this workflow. The WinGet source index builder supplies this field when building the public source index.

The schema supports `IconUrl`, `IconFileType`, `IconResolution`, `IconTheme`, and `IconSha256`, but these fields are intentionally ignored during winget-pkgs manifest authoring here.

## Sources

- [winget-pkgs authoring guide](https://github.com/microsoft/winget-pkgs/blob/master/doc/Authoring.md)
- [WinGet 1.12 default-locale schema](https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.12.0/manifest.defaultLocale.1.12.0.json)
- [WinGet 1.12 locale schema](https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.12.0/manifest.locale.1.12.0.json)
- [SPDX license list](https://spdx.org/licenses/)
