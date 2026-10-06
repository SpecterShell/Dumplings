# Locale manifest model

## Contents

- [When To Use](#when-to-use)
- [Manifest Headers](#manifest-headers)
- [Locale Selection And Inheritance](#locale-selection-and-inheritance)
- [Regional Locale Selection](#regional-locale-selection)
- [Locale URLs](#locale-urls)
- [Additional Locale Fields](#additional-locale-fields)
- [Locale Field Completeness Pass](#locale-field-completeness-pass)
- [Localization Rules](#localization-rules)
- [Validation Checklist](#validation-checklist)
- [Locale identity](identity.md)
- [Locale content and resources](content-and-resources.md)
- [Release notes](content-and-resources.md#release-notes)

## When To Use

Use this reference to author or review the `defaultLocale` manifest and any additional `locale` manifests. Use only official publisher metadata and evidence that can be tied to the package.

The default-locale manifest is the complete fallback localization. An additional locale manifest is an overlay containing only fields for which reliable localized metadata exists.

## Manifest Headers

Use the exact fixed `defaultLocale` or `locale` header from [Manifest model and files](../manifest/model-and-files.md#fixed-headers). The schema URL must use the repository-recommended version, currently `1.12.0`, and must match `ManifestVersion` and the schema version used by every other file in the manifest set.

## Locale Selection And Inheritance

- `DefaultLocale` in the version manifest must exactly equal `PackageLocale` in the default-locale manifest.
- Use a valid BCP-47 language tag for every `PackageLocale`.
- WinGet starts with the default localization, selects the closest compatible additional locale, and replaces each field supplied by that locale.
- Omitted fields inherit from the default localization.
- Arrays and structured fields such as `Tags`, `Agreements`, `Documentations`, and `Icons` replace the complete default-locale field. Their individual elements are not merged.
- `Moniker` exists only in the default-locale schema and cannot be overridden by an additional locale manifest.
- Localized `PackageName` and `Publisher` values participate in WinGet search and ARP correlation. Do not add arbitrary translations that do not represent the product's actual localized identity.
- When static parsing or VM evidence shows a localized ARP `DisplayName` or `Publisher`, put that evidenced identity in the matching locale manifest rather than `AppsAndFeaturesEntries`. Use an Apps & Features override only when the corresponding locale manifest does not exist.

## Regional Locale Selection

Do not derive the region subtag from the language alone. English does not imply `en-US`, French does not imply `fr-FR`, German does not imply `de-DE`, and Dutch does not imply `nl-NL`. `DefaultLocale` in the version manifest and `PackageLocale` in the default-locale manifest must use the same evidence-backed BCP-47 tag.

For English, this project's authoring convention uses only `en-US` and `en-GB` in default and additional locale manifests. Choose between them using the product's spelling, regional content, and target market. A Singaporean publisher's location must not produce `en-SG`. Use `en-GB` when British English is evidenced or `en-US` when American English is evidenced, and record uncertainty when neither is clear. This restriction does not apply to other languages.

Use the strongest available evidence in this order:

1. An explicit locale or market declaration in the product page, HTML language metadata, locale selector, installer metadata, application settings, store listing, feed, or API.
2. The product's stated target market, regional site, supported-country list, currency, legal terms, spelling, and other regionalized content.
3. The publisher's official contact page, legal address, company location, imprint or `Impressum`, privacy policy, terms, repository profile, or official store profile. Use publisher location as the fallback when the source establishes the language but does not declare a region.

A country-code domain or translated navigation label is supporting evidence, not a decision by itself. A multinational publisher may serve a regional product that differs from its headquarters, and a site can use another regional variety. Prefer product-specific evidence when it conflicts with company location. If the evidence remains ambiguous, record the uncertainty.

Examples:

| Evidence | Locale decision |
|---|---|
| A British publisher serves its primary product metadata in English and the legal/contact evidence places the product in the United Kingdom. | Use `en-GB`, not an automatic `en-US`. |
| A Singaporean publisher serves English product metadata with British spelling. | Use `en-GB`. |
| A Belgian publisher or individual serves the product in French. | Use `fr-BE`, not `fr-FR`. |
| A Swiss company serves a French product page for the Swiss market. | Use `fr-CH`, not `fr-FR`. |
| A Swiss company serves German metadata for a Swiss product. | Use `de-CH`, not `de-DE`. |
| An Austrian publisher serves its product in German. | Use `de-AT`, not `de-DE`. |
| A Belgian product is served in German for the Belgian market. | Use `de-BE`, not `de-DE`. |
| A Belgian organization serves Dutch metadata. | Use `nl-BE`, not `nl-NL`. |

Apply the same reasoning to additional locale manifests. Their `PackageLocale` describes the regional localization represented by that file, which can differ from both the publisher's home country and the default locale.

## Locale URLs

For default-locale URL fields, try removing explicit language or region path segments such as `/en/` or `/en-us/`. Use the locale-neutral URL when it remains publicly accessible and resolves to the equivalent official page, including through a locale redirect. Check the page content as well as the HTTP status to reject soft-404 pages and unrelated destinations. This gives visitors a chance to reach their own localization. Keep the original locale-specific URL when the stripped URL does not work. URL neutrality alone does not determine `PackageLocale`.

For additional locale manifests, keep each official URL's locale-specific path, subdomain, or query parameter. Do not strip locale markers or invent localized URLs. When no official localized equivalent exists, omit the URL field and inherit the default. Structured-array rules below still require a URL for every included item.

## Additional Locale Fields

### URL Fields

Omit a URL field when there is no official URL specifically intended for that locale. The field will inherit from the default-locale manifest.

This applies to `PublisherUrl`, `PublisherSupportUrl`, `PrivacyUrl`, `PackageUrl`, `LicenseUrl`, `CopyrightUrl`, `ReleaseNotesUrl`, `PurchaseUrl`, `Agreements[].AgreementUrl`, and `Documentations[].DocumentUrl`. Do not repeat the default URL merely to make the locale file look complete. The exception is a complete localized `Documentations` array: when translating a `DocumentLabel`, repeat its corresponding `DocumentUrl` because structured array items do not inherit individual properties.

### Non-URL Fields

- Translate a non-URL field when its content is translatable and the translation is reliable.
- Omit identifiers and invariant values that should remain unchanged, allowing them to inherit from the default locale.
- Translate non-SPDX `License` names and classifications into the language of each manifest's `PackageLocale`, including the default locale. Additional locale manifests must supply their own translated value rather than inherit a classification in another language.
- Use [GNU's terminology guide](https://www.gnu.org/philosophy/fs-translations.html) for translations. For `Freeware`, use the equivalent of its "gratis software" category to preserve the meaning of no-cost software. In `zh-CN`, use `专有软件` for `Proprietary` and `免费软件` for `Freeware`. Use the appropriate script and wording for other locales, and respect the schema's minimum length. Do not shorten the Chinese proprietary label to `专有`.
- Keep SPDX identifiers such as `MIT` and `Apache-2.0` unchanged in every locale. An additional locale may omit `License` to inherit the same SPDX identifier.
- Preserve official product names, legal company names, and technical terms unless the publisher provides an official localized form.

## Locale Field Completeness Pass

The required fields are a schema minimum, not an authoring target. For the default locale, actively check every applicable optional field before finalizing:

- Publisher identity and contact: `PublisherUrl`, `PublisherSupportUrl`, `PrivacyUrl`, and `Author`.
- Product identity and legal metadata: `PackageUrl`, `LicenseUrl`, `Copyright`, and qualifying `CopyrightUrl`.
- Discovery and explanation: `Description`, `Moniker`, and `Tags`.
- Commercial information: `PurchaseUrl` when the package has an official purchase option.
- License acceptance: `Agreements` only when unattended installation requires explicit license-acceptance arguments, as described in [Agreements](content-and-resources.md#agreements).
- Release and operation: version-specific `ReleaseNotes`, `ReleaseNotesUrl`, and necessary `InstallationNotes`.
- Help resources: useful official `Documentations`, including an enabled and populated repository Wiki where applicable.

Search the official product, download, support, contact, privacy, terms/license, purchase, documentation, FAQ, and release-history pages. `Icons` is excluded by this project.

For an additional locale, perform the same applicability review but include only reliable localized overrides. Translate translatable licenses, descriptions, tags, documentation labels, and installation notes when evidence permits. Omit invariant or unavailable values so they inherit from the default locale. Do not copy default-language prose merely to increase field count.

## Localization Rules

- Translate descriptive metadata, labels, notes, and documentation links only from reliable localized sources.
- Omit locale-specific URL fields when no official localized URL exists. Inherit the default URL instead.
- Translate translatable non-URL fields rather than copying default-language prose unchanged.
- Preserve official localized product and publisher names when the publisher uses them.
- Do not translate legal company names, product names, monikers, or technical terms unless the publisher does so officially. Follow the [license translation rules](#non-url-fields) for `License`.
- A localized URL may override the default URL when it leads to the equivalent official page in that locale.
- Omit an optional localized field to inherit the default value rather than copying unchanged text into every locale file.
- Translate `Tags` when useful localized search terms exist. Otherwise omit the additional-locale `Tags` field. When overriding it, provide the complete desired array.
- Translate `Documentations[].DocumentLabel` when useful localized labels exist. Otherwise omit the additional-locale `Documentations` field. When overriding it, provide the complete array and repeat each required `DocumentUrl`.
- Because each supplied field replaces the default field completely, repeat the full intended array or object in a locale file when overriding `Tags`, `Agreements`, `Documentations`, or another structured field.

## Validation Checklist

- The default locale matches the version manifest's `DefaultLocale`.
- The region subtag follows the regional evidence rules. English uses only `en-US` or `en-GB`, and other languages retain their evidenced regions.
- The file begins with the exact fixed header for `defaultLocale` or `locale`, and its versioned schema URL matches `ManifestVersion`.
- Every locale tag is valid BCP-47 and unique in the manifest set.
- Required default-locale fields are present.
- Select `Publisher` and `PackageName` using the [locale identity rules](identity.md), including the repository-owner preference when the ARP publisher repeats the application name.
- Every evidenced localized ARP name or publisher is represented in its corresponding locale manifest when that locale exists, rather than duplicated in `AppsAndFeaturesEntries`.
- The new package identifier's publisher segment and `Author` reflect the product's actual retained developer identity. Acquisition or parent-company ownership was not treated as an automatic rename.
- Any missing ARP publisher is compensated by an independent matching identity or explicitly reported as a correlation risk.
- Every URL is official, public, and appropriate for its field.
- Default-locale URLs use verified locale-neutral equivalents where available. Additional-locale URLs retain their locale markers.
- `PackageName` preserves major-version, architecture, and channel distinctions encoded by the package identifier.
- `License` uses the correct unchanged SPDX identifier or an evidenced non-SPDX label translated for that manifest's locale.
- Tags follow the lower-case, hyphen-separated convention and describe user-facing discovery terms rather than implementation technology or generic application form.
- Tags are sorted and deduplicated with the `en-US` culture in every locale manifest.
- Additional-locale tags are translated when useful, or omitted when no tag is translatable.
- GitHub Wiki availability was checked for repository-hosted packages, and additional-locale documentation is present only when its labels are translated.
- `Agreements` appears only when explicit unattended acceptance is required.
- `Icons` is omitted.
- Additional locales contain only evidenced localized overrides.
- Every default-locale optional field was checked against its likely official source, even when ultimately omitted.
- Every additional-locale field is a useful localized override rather than an unchanged duplicate.
- The complete manifest set has passed through logical-model serialization after authoring. `Format-WinGetManifest` is only the fallback for an isolated draft.
