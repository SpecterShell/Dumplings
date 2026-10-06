# Locale content and resources

## License And Copyright

### License

- For an open-source package with a valid SPDX license, use its [SPDX license identifier](https://spdx.org/licenses/), such as `MIT`, `Apache-2.0`, or `GPL-3.0-only`. Verify that the repository or distributed source actually contains the full license text that grants permission, whether in a license file, complete source-file headers, or another complete license section. Search the SPDX list when the identifier is unfamiliar.
- Use `Freeware` for a non-open-source package that is explicitly free to use and is not shareware.
- Use `Proprietary` when the package uses a proprietary license and should not be classified as freeware, or when no more specific public classification is available.
- Do not treat a copyright notice, source-available statement, public repository, license badge, package metadata value, or a README sentence that merely names a license as the license grant. If the project claims an open-source license but provides no license text, do not write that SPDX identifier. Use `Freeware` when the publisher still clearly distributes the application for free. Otherwise use `Proprietary` until authoritative terms are available.

Translate non-SPDX license labels for each manifest's `PackageLocale`, including the default locale. Keep SPDX identifiers unchanged. Follow the [license localization rules](model.md#non-url-fields).

### LicenseUrl

- For an open-source repository, link to the rendered license file on the repository's default branch using a stable branch alias such as `HEAD`, for example `https://github.com/CherryHQ/cherry-studio/blob/HEAD/LICENSE`.
- Do not use a README license badge, heading, or one-line license claim as `LicenseUrl` when the linked page does not contain the license text. Omit `LicenseUrl` unless another official page provides the applicable terms.
- For proprietary or freeware applications, use the official license agreement, terms of service, or end-user license page.
- The site footer, login page, and installer wizard are useful discovery locations. A URL written to the manifest must remain publicly accessible without running the installer.

### Copyright

Use the package's copyright statement from the application About page or window, the official site footer, or the PE `LegalCopyright` version-resource field. Also check the product license linked by `LicenseUrl`, including MIT or Apache-2.0 projects and associated `NOTICE` files, and the publisher's copyright or legal page linked by a qualifying `CopyrightUrl`. Preserve the published wording and year range. Exclude unfilled license-template placeholders and notices that apply only to third-party components.

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

Use a longer official product description when it adds useful detail beyond `ShortDescription`. `Description` supports multiline text, usually written as a YAML literal block with `Description: |-`. Combine relevant introduction, feature, and capability sections from the official product page or repository README in source order. Preserve useful paragraphs, section labels, and plain-text feature lists.

Select sections that explain the application. Exclude installation and build instructions, download links and checksum sections, screenshots and videos, badges, license and copyright text, sponsors, and donation requests. Keep useful textual feature explanations beside screenshots while omitting the media. Put license and copyright evidence in their dedicated fields.

Convert selected HTML nodes or Markdown sections with `Get-TextContent | Format-Text`, using `Convert-MarkdownToHtml` first for Markdown. See the shared [text and structured-data functions](../../../use-dumplings-functions/references/content-data.md) for these contracts. Review the selected sections before conversion rather than passing the entire README. Light edits for neutrality and clarity are allowed without changing factual claims. Keep the result within the schema's 10,000-character limit by removing less relevant material.

Examples from packages authored in January–June 2026 and maintained by Dumplings:

- [hellodigua.ChatLab 0.9.3](https://github.com/microsoft/winget-pkgs/blob/84a62fd01198b9002a8a46bcbee5a38500aba2a7/manifests/h/hellodigua/ChatLab/0.9.3/hellodigua.ChatLab.locale.en-US.yaml) combines an introduction and supported chat sources with a core-feature list covering privacy, analysis, and visualization.
- [codedogQBY.ReadAny 1.3.1](https://github.com/microsoft/winget-pkgs/blob/5fb2b1ff96bba80c7a4869e012b10fa61a270adb/manifests/c/codedogQBY/ReadAny/1.3.1/codedogQBY.ReadAny.locale.en-US.yaml) combines a brief introduction with several feature sections, including reading, annotation, speech, statistics, and synchronization.

Product introductions and feature descriptions belong in `Description`. Keep `ReleaseNotes` limited to changes in the selected release and follow the [release-note rules](#release-notes).

### Moniker

Do not add `Moniker` automatically for a new package, even when the product name, executable, command, or package identifier suggests an obvious alias. Keep the field only in the default-locale manifest when the task explicitly requires a short, distinctive, commonly recognized moniker. Preserve an existing package's established moniker during routine updates unless evidence shows that it is incorrect.

### Tags

- Use short, relevant, lower-case search terms.
- Separate words within one multiword tag with hyphens, not spaces or underscores.
- Do not hyphenate a term merely to combine unrelated keywords.
- Use existing winget-pkgs manifests as style examples, but verify that every retained tag describes the current package.
- Avoid publisher names, generic terms such as `software`, and speculative capabilities that do not improve discovery.
- Describe user-facing purpose, workflows, formats, or capabilities. Add language or framework tags such as `electron`, `tauri`, or `rust` only when the package develops for them.
- Omit generic application-form tags such as `desktop`, `cli`, and `command-line`.
- In an additional locale manifest, translate tags that have natural, useful localized search terms.
- If no tags are translatable, omit `Tags` from the additional locale to inherit the default array.
- If only some tags are translatable, supply the complete intended localized array because `Tags` arrays do not merge. Keep invariant technical terms and replace only the terms that have useful translations.
- Sort and deduplicate `Tags` deterministically with the `en-US` culture in every default and additional locale manifest.

Sort with PowerShell 7.4 or later.

```powershell
$Tags | Sort-Object -Culture en-US -Unique
```

Windows PowerShell 5 does not handle `-Culture` reliably for this workflow.

## Agreements And Documentation

### Agreements

Add `Agreements` only when unattended installation requires explicit license acceptance through installer arguments, such as `ACCEPT_EULA=1` for `Microsoft.PowerBI`.

- `AgreementLabel`: a concise name for the agreement.
- `AgreementUrl`: the official public agreement URL.

Do not add an agreement merely because every application has a license or terms of service. Keep installer acceptance switches in the installer manifest as well.

### Documentations

Use `Documentations` for official manuals, getting-started guides, administration guides, or troubleshooting pages.

- `DocumentLabel`: a short label based on the page title, URL, or link text, such as "Documentation", "User Guide", or "Wiki".
- `DocumentUrl`: the official documentation URL.
- For a package hosted in a GitHub repository, check whether the repository has an enabled, populated Wiki and add that official Wiki when it provides useful package documentation.
- Do not duplicate `PackageUrl` or marketing pages. Put support and contact pages in `PublisherSupportUrl`.
- In an additional locale manifest, include `Documentations` only when at least one `DocumentLabel` has a useful translation. Translate the labels and supply the complete intended array, including each corresponding URL.
- If the labels are proper names, technical identifiers, or otherwise not translatable, omit `Documentations` from the additional locale manifest and inherit the default-locale array.

## Release notes

Use this section for `ReleaseNotes` and `ReleaseNotesUrl` in default and additional locale manifests. Follow [release date evidence](../package/release-date.md) for the installer manifest's `ReleaseDate`.

### Find the source

Git-hosted applications may publish installers through repository releases even when the application itself is closed source. Treat the official repository and its release pages as valid first-party sources. `InTheLoop.LoopEmail` is an example of this distribution model.

For GitHub, GitLab, Gitea, Codeberg, Bitbucket, Gitee, GitCode, and similar platforms, inspect release-note sources in this order:

1. The body of the exact release that provides the selected desktop installer.
2. A version entry in a repository-root release history such as `CHANGELOG.md`, `RELEASES.md`, or `CHANGES.md`, including case and naming variants.
3. The desktop application's official homepage, documentation, support site, or dedicated release-history page.

A release body is not valid release notes merely because it exists. Reject an empty body, a body containing only the version/title, generated assets or download links, checksums, or other text that does not describe product changes. For example, the [ImageMagick 7.1.2-27 release](https://github.com/ImageMagick/ImageMagick/releases/tag/7.1.2-27) contains no substantive change list, so use the repository release-history files or official site instead.

For applications not released through a Git platform, search the official site footer, download page, support pages, and documentation. Confirm that the selected page describes the Windows desktop application. Do not use platform-service updates, server-only changes, web-product updates, or mobile-app release notes for a desktop manifest.

Record two sources separately:

- The raw HTML or Markdown source used to build `ReleaseNotes`.
- The human-readable official page used as `ReleaseNotesUrl`, preferably a version-specific release page or changelog anchor rather than a raw-content URL.

### Format the release text

Use the selected version-specific desktop release-note source. Do not summarize, paraphrase, or rewrite it. Scrape the raw HTML or Markdown, remove only unrelated material such as download links, asset tables, checksums, mobile-only changes, or platform updates, then preserve the remaining processed text verbatim.

Omit entire download and hash/checksum sections, especially in GitHub release bodies. Remove their headings, asset lists, checksum tables, hash values, and verification instructions. Removing only the heading leaves the unwanted content in the manifest. Preserve actual change entries that discuss downloads or hashing as product features.

Filter by the source's observed headings and section boundaries before `Get-TextContent`. The task-authoring [section-filtering recipe](../../../author-dumplings-task/references/release/html-markdown.md#skip-download-and-hash-sections) shows a persistent `$Skip` flag and lists current task examples. Skip standalone asset-hash tables too. If no product changes remain, omit `ReleaseNotes` and look for a substantive changelog or official release-history page.

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

GitHub release bodies and other Markdown sources that treat each single newline as a visual line break require `hardlinebreak`. For Markdown already limited to the selected changes:

```powershell
$ReleaseNotes = $ReleaseNotesMarkdown | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
```

Filter irrelevant sections from the raw source before the conversion pipeline when possible. If filtering the parsed HTML is safer, select only the release-note nodes before `Get-TextContent`. Do not reconstruct the remaining content in different words. The output of `Format-Text` is the manifest text. Omit `ReleaseNotes` when no reliable version-specific desktop text exists.

### Choose the release-notes URL

Use the human-readable official page that supports the selected text. Prefer the exact Git-platform release page when its body contains valid desktop release notes. When text came from a repository release-history file, use its rendered file page with a version anchor when available. Otherwise use the versioned desktop release-history page on the official site.

Do not use a release URL whose body is empty or unrelated merely because the installer asset is attached there. In that case, point to the fallback changelog or official desktop release-notes page. Do not use raw-content URLs as `ReleaseNotesUrl` when a rendered page is available.

## Purchase and installation information

### PurchaseUrl

Use the official purchase, subscription, pricing, or entitlement page. Omit it when the package has no purchase option. Donation pages do not qualify.

### InstallationNotes

Use only for information the user needs after installation, such as a required first-run action or configuration step. Do not repeat installer switches or generic success messages.

## Icons

Do not author `Icons` for winget-pkgs manifests in this workflow. The WinGet source index builder supplies this field when building the public source index.

The schema supports `IconUrl`, `IconFileType`, `IconResolution`, `IconTheme`, and `IconSha256`. Leave these fields to the source index builder.

## Sources

- [winget-pkgs authoring guide](https://github.com/microsoft/winget-pkgs/blob/master/doc/Authoring.md)
- [WinGet 1.12 default-locale schema](https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.12.0/manifest.defaultLocale.1.12.0.json)
- [WinGet 1.12 locale schema](https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.12.0/manifest.locale.1.12.0.json)
- [SPDX license list](https://spdx.org/licenses/)
