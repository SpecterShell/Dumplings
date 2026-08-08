# Locale manifest model

## Contents

- [When To Use](#when-to-use)
- [Manifest Headers](#manifest-headers)
- [Locale Selection And Inheritance](#locale-selection-and-inheritance)
- [Additional Locale Fields](#additional-locale-fields)
- [Locale Field Completeness Pass](#locale-field-completeness-pass)
- [Localization Rules](#localization-rules)
- [Validation Checklist](#validation-checklist)
- [Locale identity](identity.md)
- [Locale content and resources](content-and-resources.md)

## When To Use

Use this reference to author or review the `defaultLocale` manifest and any additional `locale` manifests. Use only official publisher metadata and evidence that can be tied to the package.

The default-locale manifest is the complete fallback localization. An additional locale manifest is an overlay containing only fields for which reliable localized metadata exists.

## Manifest Headers

Use the exact fixed `defaultLocale` or `locale` header from [Manifest model and files](../manifest/model-and-files.md#fixed-headers). The schema URL must use the latest stable version, currently `1.12.0`, and must match `ManifestVersion` and the schema version used by every other file in the manifest set.

## Locale Selection And Inheritance

- `DefaultLocale` in the version manifest must exactly equal `PackageLocale` in the default-locale manifest.
- Use a valid BCP-47 language tag for every `PackageLocale`.
- WinGet starts with the default localization, selects the closest compatible additional locale, and replaces each field supplied by that locale.
- Omitted fields inherit from the default localization.
- Arrays and structured fields such as `Tags`, `Agreements`, `Documentations`, and `Icons` replace the complete default-locale field. Their individual elements are not merged.
- `Moniker` exists only in the default-locale schema and cannot be overridden by an additional locale manifest.
- Localized `PackageName` and `Publisher` values participate in WinGet search and ARP correlation. Do not add arbitrary translations that do not represent the product's actual localized identity.
- When static parsing or VM evidence shows a localized ARP `DisplayName` or `Publisher`, put that evidenced identity in the matching locale manifest rather than `AppsAndFeaturesEntries`. Use an Apps & Features override only when the corresponding locale manifest does not exist.

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

## Locale Field Completeness Pass

The required fields are a schema minimum, not an authoring target. For the default locale, actively check every applicable optional field before finalizing:

- Publisher identity and contact: `PublisherUrl`, `PublisherSupportUrl`, `PrivacyUrl`, and `Author`.
- Product identity and legal metadata: `PackageUrl`, `LicenseUrl`, `Copyright`, and qualifying `CopyrightUrl`.
- Discovery and explanation: `Description`, `Moniker`, and `Tags`.
- Commercial and legal interaction: `PurchaseUrl` and `Agreements` when explicit unattended acceptance is required.
- Release and operation: version-specific `ReleaseNotes`, `ReleaseNotesUrl`, and necessary `InstallationNotes`.
- Help resources: useful official `Documentations`, including an enabled and populated repository Wiki where applicable.

Search the official product, download, support, contact, privacy, terms/license, purchase, documentation, FAQ, and release-history pages rather than stopping at the package homepage. Corroborate `Author` with official legal/product evidence and installer metadata without fabricating a legal-name expansion. `Icons` remains intentionally excluded by this project.

For an additional locale, perform the same applicability review but include only reliable localized overrides. Translate translatable descriptions, classifications, tags, documentation labels, release notes, and installation notes when evidence permits; omit invariant or unavailable values so they inherit from the default locale. Do not copy default-language prose merely to increase field count.

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
- Every evidenced localized ARP name or publisher is represented in its corresponding locale manifest when that locale exists, rather than duplicated in `AppsAndFeaturesEntries`.
- The new package identifier's publisher segment and `Author` reflect the product's actual retained developer identity; acquisition or parent-company ownership was not treated as an automatic rename.
- Any missing ARP publisher is compensated by an independent matching identity or explicitly reported as a correlation risk.
- Every URL is official, public, and appropriate for its field.
- `PackageName` preserves major-version, architecture, and channel distinctions encoded by the package identifier.
- `License` uses the correct SPDX identifier or justified `Freeware`/`Proprietary` classification.
- Tags follow the lower-case, hyphen-separated convention and describe user-facing discovery terms rather than implementation technology or generic application form.
- Tags are sorted and deduplicated with the `en-US` culture in every locale manifest.
- Additional-locale tags are translated when useful, or omitted when no tag is translatable.
- GitHub Wiki availability was checked for repository-hosted packages, and additional-locale documentation is present only when its labels are translated.
- `Agreements` appears only when explicit unattended acceptance is required.
- `Icons` is omitted.
- Additional locales contain only evidenced localized overrides.
- Every default-locale optional field was checked against its likely official source, even when ultimately omitted.
- Every additional-locale field is a useful localized override rather than an unchanged duplicate.
- The complete manifest set has passed through logical-model serialization after authoring; `Format-WinGetManifest` is only the fallback for an isolated draft.
