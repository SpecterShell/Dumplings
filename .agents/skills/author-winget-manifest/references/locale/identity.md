# Locale identity

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
