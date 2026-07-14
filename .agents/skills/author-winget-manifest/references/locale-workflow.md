# Locale Manifest Workflow

## Contents

- [When To Use](#when-to-use)
- [Manifest Headers](#manifest-headers)
- [Locale Selection And Inheritance](#locale-selection-and-inheritance)
- [Additional Locale Fields](#additional-locale-fields)
- [Required Identity Fields](#required-identity-fields)
- [Package Identifier Ownership](#package-identifier-ownership)
- [Publisher And Author](#publisher-and-author)
- [Package Identity And URLs](#package-identity-and-urls)
- [License And Copyright](#license-and-copyright)
- [Descriptions And Discovery](#descriptions-and-discovery)
- [Agreements And Documentation](#agreements-and-documentation)
- [Release And Installation Information](#release-and-installation-information)
- [Icons](#icons)
- [Localization Rules](#localization-rules)
- [Validation Checklist](#validation-checklist)
- [Sources](#sources)

## When To Use

Use this reference to author or review the `defaultLocale` manifest and any additional `locale` manifests. Use only official publisher metadata and evidence that can be tied to the package.

The default-locale manifest is the complete fallback localization. An additional locale manifest is an overlay containing only fields for which reliable localized metadata exists.

## Manifest Headers

Use the exact fixed `defaultLocale` or `locale` header from [Installer Manifest Workflow](manifest-workflow.md#fixed-headers). The schema URL must use the latest stable version, currently `1.12.0`, and must match `ManifestVersion` and the schema version used by every other file in the manifest set.

## Locale Selection And Inheritance

- `DefaultLocale` in the version manifest must exactly equal `PackageLocale` in the default-locale manifest.
- Use a valid BCP-47 language tag for every `PackageLocale`.
- WinGet starts with the default localization, selects the closest compatible additional locale, and replaces each field supplied by that locale.
- Omitted fields inherit from the default localization.
- Arrays and structured fields such as `Tags`, `Agreements`, `Documentations`, and `Icons` replace the complete default-locale field. Their individual elements are not merged.
- `Moniker` exists only in the default-locale schema and cannot be overridden by an additional locale manifest.
- Localized `PackageName` and `Publisher` values participate in WinGet search and ARP correlation. Do not add arbitrary translations that do not represent the product's actual localized identity.

## Additional Locale Fields

### URL Fields

Omit a URL field when there is no official URL specifically intended for that locale. The field will inherit from the default-locale manifest.

This applies to `PublisherUrl`, `PublisherSupportUrl`, `PrivacyUrl`, `PackageUrl`, `LicenseUrl`, `CopyrightUrl`, `ReleaseNotesUrl`, `PurchaseUrl`, `Agreements[].AgreementUrl`, and `Documentations[].DocumentUrl`. Do not repeat the default URL merely to make the locale file look complete. The exception is a complete localized `Documentations` array: when translating a `DocumentLabel`, repeat its corresponding `DocumentUrl` because structured array items do not inherit individual properties.

### Non-URL Fields

- Translate a non-URL field when its content is translatable and the translation is reliable.
- Omit identifiers and invariant values that should remain unchanged, allowing them to inherit from the default locale. For example, omit `License: MIT` from an additional locale manifest.
- Localize license classifications when appropriate. In a Chinese locale, translate `License: Proprietary` to `License: 专有软件` and `License: Freeware` to `License: 免费软件`.
- Apply those `License` translations only to Chinese locale manifests. In particular, do not use `专有` alone because it is shorter than the schema's minimum length for `License`.
- Preserve official product names, legal company names, SPDX identifiers, and technical terms unless the publisher provides an official localized form.

## Required Identity Fields

Every default-locale manifest requires:

- `PackageIdentifier`: the stable, case-sensitive package identity matching the manifest path.
- `PackageVersion`: the release identity shared by every file in the manifest set.
- `PackageLocale`: the BCP-47 language tag for the default metadata.
- `Publisher`: the publisher identity selected according to the rules below.
- `PackageName`: the user-facing package name selected according to the rules below.
- `License`: the license identifier or classification selected according to the rules below.
- `ShortDescription`: a concise explanation of what the application does.
- `ManifestType`: `defaultLocale`.
- `ManifestVersion`: the schema version used by the complete manifest set.

An additional locale manifest requires only `PackageIdentifier`, `PackageVersion`, `PackageLocale`, `ManifestType: locale`, and `ManifestVersion`. Add optional fields only when localized evidence exists.

## Package Identifier Ownership

For a new package, choose the publisher segment of `PackageIdentifier` from the authoritative company, organization, or individual under which the product retains its identity. Ultimate parent-company ownership does not automatically replace an acquired company's product namespace.

Establish these facts separately:

1. Product identity: current product branding, package page, application name, and official store or repository identity.
2. Product developer or author: official product history, About text, documentation, acquisition announcement, and corroborating binary metadata.
3. Installed identity: visible ARP `Publisher`, `DisplayName`, `ProductCode`, and other matching evidence.
4. Corporate ownership: official acquisition, merger, or ownership announcements.
5. Current legal controller: privacy policy, EULA, terms, and other legal pages, which may name a parent company without making it the software author.

Keep these identities separate:

- `PackageIdentifier` publisher segment represents the product's retained publisher/developer identity for a new submission.
- `Publisher` normally preserves the visible ARP publisher for installed-package correlation.
- `Author` identifies the company, organization, or individual that authors or develops the application, not necessarily its ultimate parent or privacy-policy controller.
- `PublisherUrl`, `PrivacyUrl`, `LicenseUrl`, support, and documentation may legitimately point to the acquiring parent company's current sites.
- Authenticode signer is installer provenance evidence. It can corroborate the acquired company's legal name when it aligns with product and acquisition evidence, but should not be used alone.

Acquisition example:

```yaml
PackageIdentifier: 7pace.Timetracker
Publisher: 7pace
Author: 7pace GmbH
PackageName: 7pace Timetracker
PublisherUrl: https://appfire.com/
```

Appfire's [7pace acquisition announcement](https://appfire.com/resources/blog/appfire-acquires-7pace) establishes that Appfire acquired 7pace, not that the 7pace product identity ceased to exist. The application remains branded and published as 7pace Timetracker, writes `Publisher: 7pace`, and is signed by `7pace GmbH`. Therefore use the acquired company for `PackageIdentifier` and `Author`, preserve the ARP publisher, and use Appfire's current sites for publisher, privacy, support, and legal URLs.

Use the acquiring parent for `PackageIdentifier` or `Author` only when official evidence shows that the product was actually rebranded, republished, or transferred into the parent's product identity. Acquisition by itself is insufficient.

Do not rename an existing WinGet package merely because ownership changed; package identifiers are stable identities. Apply this ownership rule when selecting an identifier for a new package, or follow an explicit migration/replacement process when an existing identifier must change.

## Publisher And Author

### Publisher

- Prefer the visible ARP entry's `Publisher` value exactly, including its legal suffix and spelling.
- If the visible ARP entry has no `Publisher`, use another authoritative publisher identity, normally the same organization or person selected for `Author`.
- A substituted manifest publisher cannot participate in name-and-publisher matching against an ARP entry that has no publisher. It does not interfere with matching when `ProductCode`, `UpgradeCode`, `PackageFamilyName`, or another independent identity field provides the match.
- Do not assume the substitution is harmless when no independent matching identity exists. Record that the installed entry cannot be correlated by normalized name and publisher alone.

WinGet records the ARP registry key as `ProductCode` independently of `Publisher`. It adds an installed publisher only when the ARP `Publisher` value is a string, and constructs normalized name-and-publisher references only when both collections contain values. See winget-cli [`ARPHelper.cpp`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/Microsoft/ARPHelper.cpp), [`CompositeSource.cpp`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/CompositeSource.cpp), and [`ARPCorrelation.cpp`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/ARPCorrelation.cpp).

### PublisherUrl

Use the official publisher homepage:

- Usually use the site root corresponding to `PackageUrl`. For `PackageUrl: https://www.google.com/chrome/`, use `PublisherUrl: https://www.google.com/`.
- For a repository-hosted package, prefer the publisher's official website linked from the repository owner profile.
- If no separate official site exists, use the repository owner profile, such as `https://github.com/example`.
- Do not use a third-party download site, company-information directory, or repository releases page.

### PublisherSupportUrl

Use, in order of preference:

1. The official product support page.
2. The publisher's official contact page.
3. The repository issue tracker for a repository-hosted project.

Do not use a `mailto:` link.

### PrivacyUrl

Use the official privacy policy. Look for it in the site's header, footer, navigation menu, login or registration page, or a privacy document in the official repository. Prefer a package-specific policy when one exists.

### Author

- For an organization or company, use its full legal name, such as `Microsoft Corporation`, `Google LLC`, `Beijing Microlive Vision Technology Co., Ltd.`, or `Spotify AB`.
- For an individual, use the person's full name rather than only a handle when the full name is publicly established.
- Determine who authors or develops the application from the package page, product history, documentation, About page, official repository or store profile, and acquisition announcements. Do not substitute the ultimate parent company merely because it owns the developer.
- Privacy policies, EULAs, terms, and legal pages can identify the current owner or legal controller without identifying the product's author. Use them as ownership context rather than automatic `Author` values.
- Treat the ARP entry, executable metadata, and installer signing certificate as supporting evidence. A valid certificate proves who signed that binary and can corroborate a legal developer name when other official evidence agrees.
- Do not use a certificate subject as the sole source for `Author` or the `PackageIdentifier` publisher segment; signing services, build vendors, and stale certificates remain possible.
- For publishers in mainland China, ICP registration and corporate registry information can provide corroborating evidence. Services such as [QCC](https://www.qcc.com/) and [Tianyancha](https://www.tianyancha.com/) are evidence sources only; never use them as publisher or package URLs.
- Cross-check developer, brand, ownership, and legal identities independently when evidence differs. An acquisition changes ownership context, but the acquired company can remain the correct `Author` and identifier namespace.
- Do not infer or expand a legal name from a brand, account name, certificate subject, or domain without current official corroboration.

## Package Identity And URLs

### PackageName

Start from the visible ARP `DisplayName` and remove only text that is not part of the package identity:

- Remove the release version, architecture, unnecessary bracketed qualifiers, and unrelated text such as `Uninstall Only`.
- Preserve the major version when separate package identifiers track major release lines. For example, use `Microsoft .NET Windows Desktop Runtime 7` for `Microsoft.DotNet.DesktopRuntime.7`.
- Preserve architecture when separate identifiers track architectures. For example, use `Microsoft Visual C++ v14 Redistributable (x64)` for an x64 `Microsoft.VCRedist` package.
- Preserve the release channel when separate identifiers track channels. For example, use `PixPin (Beta)` for `PixPin.PixPin.Beta`.
- Do not remove a qualifier that distinguishes this package from another package identifier.

### PackageUrl

Use an official URL in this order of preference:

1. The package's product or download page.
2. The package homepage.
3. The official source repository page.

For repository-hosted packages, use the repository page rather than its releases page. Never use a third-party download or software-listing page.

## License And Copyright

### License

- For an open-source package with a valid SPDX license, use its [SPDX license identifier](https://spdx.org/licenses/), such as `MIT`, `Apache-2.0`, or `GPL-3.0-only`.
- Use `Freeware` for a non-open-source package that is explicitly free to use and is not shareware.
- Use `Proprietary` when the package uses a proprietary license and should not be classified as freeware, or when no more specific public classification is available.
- Do not treat a copyright notice, source-available statement, or the mere presence of a public repository as an open-source license.

### LicenseUrl

- For an open-source repository, link to the rendered license file on the repository's default branch using a stable branch alias such as `HEAD`, for example `https://github.com/CherryHQ/cherry-studio/blob/HEAD/LICENSE`.
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

Use one short, distinctive, commonly recognized command or search alias. Keep it only in the default-locale manifest. Omit it when no unambiguous moniker exists.

### Tags

- Use short, relevant, lower-case search terms.
- Separate words within one multiword tag with hyphens, not spaces or underscores.
- Do not hyphenate a term merely to combine unrelated keywords.
- Use existing winget-pkgs manifests as style examples, but verify that every retained tag describes the current package.
- Avoid publisher names, generic terms such as `software`, and speculative capabilities that do not improve discovery.
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
- `Agreement`: agreement text when policy permits and text is necessary.
- `AgreementUrl`: the official public agreement URL.

Do not add an agreement merely because every application has a license or terms of service. Keep installer acceptance switches in the installer manifest as well.

### Documentations

Use `Documentations` for useful official manuals, getting-started guides, administration guides, or troubleshooting pages:

- `DocumentLabel`: the user-facing label.
- `DocumentUrl`: the official documentation URL.
- For a package hosted in a GitHub repository, check whether the repository has an enabled, populated Wiki and add that official Wiki when it provides useful package documentation.
- In an additional locale manifest, include `Documentations` only when at least one `DocumentLabel` has a useful translation. Translate the labels and supply the complete intended array, including each corresponding URL.
- If the labels are proper names, technical identifiers, or otherwise not translatable, omit `Documentations` from the additional locale manifest and inherit the default-locale array.

Do not duplicate `PackageUrl`, `PublisherSupportUrl`, or unrelated marketing pages.

## Release And Installation Information

### ReleaseNotes

Use the version-specific desktop release-note source selected in `package-discovery-workflow.md`. Do not summarize, paraphrase, or rewrite it. Scrape the raw HTML or Markdown, remove only unrelated material such as download links, asset tables, checksums, mobile-only changes, or platform updates, then preserve the remaining processed text verbatim.

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
$ReleaseNotes = $Release.body |
  Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' |
  Get-TextContent |
  Format-Text
```

Filter irrelevant sections from the raw source before the conversion pipeline when possible. If filtering the parsed HTML is safer, select only the release-note nodes before `Get-TextContent`. Do not reconstruct the remaining content in different words. The output of `Format-Text` is the manifest text.

If the exact release body has no substantive desktop changes, fall back to the matching version section in a repository-root release-history file, then to the official desktop product's release-notes page. Omit `ReleaseNotes` when no reliable version-specific desktop text exists.

### ReleaseNotesUrl

Use the human-readable official page that supports the selected text. Prefer the exact Git-platform release page when its body contains valid desktop release notes. When text came from a repository release-history file, use its rendered file page with a version anchor when available. Otherwise use the versioned desktop release-history page on the official site.

Do not use a release URL whose body is empty or unrelated merely because the installer asset is attached there. In that case, point to the fallback changelog or official desktop release-notes page. Do not use raw-content URLs as `ReleaseNotesUrl` when a rendered page is available.

### PurchaseUrl

Use the official purchase, subscription, or entitlement page. Omit it for packages that have no purchasing flow.

### InstallationNotes

Use only for information the user needs after installation, such as a required first-run action or configuration step. Do not repeat installer switches or generic success messages.

## Icons

Do not author `Icons` for winget-pkgs manifests in this workflow. The WinGet source index builder supplies this field when building the public source index.

The schema supports `IconUrl`, `IconFileType`, `IconResolution`, `IconTheme`, and `IconSha256`, but these fields are intentionally ignored during winget-pkgs manifest authoring here.

## Localization Rules

- Translate descriptive metadata, labels, notes, and documentation links only from reliable localized sources.
- Omit locale-specific URL fields when no official localized URL exists; inherit the default URL instead.
- Translate translatable non-URL fields rather than copying default-language prose unchanged.
- Preserve official localized product and publisher names when the publisher uses them.
- Do not translate legal company names, product names, licenses, monikers, or technical terms unless the publisher does so officially.
- A localized URL may override the default URL when it leads to the equivalent official page in that locale.
- Omit an optional localized field to inherit the default value rather than copying unchanged text into every locale file.
- Translate `Tags` when useful localized search terms exist; otherwise omit the additional-locale `Tags` field. When overriding it, provide the complete desired array.
- Translate `Documentations[].DocumentLabel` when useful localized labels exist; otherwise omit the additional-locale `Documentations` field. When overriding it, provide the complete array and repeat each required `DocumentUrl`.
- Because each supplied field replaces the default field completely, repeat the full intended array or object in a locale file when overriding `Tags`, `Agreements`, `Documentations`, or another structured field.

## Validation Checklist

- The default locale matches the version manifest's `DefaultLocale`.
- The file begins with the exact fixed header for `defaultLocale` or `locale`, and its versioned schema URL matches `ManifestVersion`.
- Every locale tag is valid BCP-47 and unique in the manifest set.
- Required default-locale fields are present.
- `Publisher` and `PackageName` reflect visible ARP identity where available.
- The new package identifier's publisher segment and `Author` reflect the product's actual retained developer identity; acquisition or parent-company ownership was not treated as an automatic rename.
- Any missing ARP publisher is compensated by an independent matching identity or explicitly reported as a correlation risk.
- Every URL is official, public, and appropriate for its field.
- `PackageName` preserves major-version, architecture, and channel distinctions encoded by the package identifier.
- `License` uses the correct SPDX identifier or justified `Freeware`/`Proprietary` classification.
- Tags follow the lower-case, hyphen-separated convention.
- Tags are sorted and deduplicated with the `en-US` culture in every locale manifest.
- Additional-locale tags are translated when useful, or omitted when no tag is translatable.
- GitHub Wiki availability was checked for repository-hosted packages, and additional-locale documentation is present only when its labels are translated.
- `Agreements` appears only when explicit unattended acceptance is required.
- `Icons` is omitted.
- Additional locales contain only evidenced localized overrides.

## Sources

- [winget-pkgs authoring guide](https://github.com/microsoft/winget-pkgs/blob/master/doc/Authoring.md)
- [WinGet 1.12 default-locale schema](https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.12.0/manifest.defaultLocale.1.12.0.json)
- [WinGet 1.12 locale schema](https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.12.0/manifest.locale.1.12.0.json)
- [SPDX license list](https://spdx.org/licenses/)
