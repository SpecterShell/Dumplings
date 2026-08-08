# Package identity

## Goal

Find the official, public, version-specific installer source before authoring any manifest. Treat source discovery as a security task, not just a download task.

## Existing Package Discovery

Before creating a package or recursively searching the large winget-pkgs manifest tree, query the installed WinGet source:

```powershell
winget search 'Product Name' --source winget
winget search --id Publisher.Package --exact --source winget
winget show --id Publisher.Package --exact --source winget
```

Use a broad product-name search first when the identifier is unknown. Search likely publisher/brand spellings as needed, then confirm the exact identifier with `winget show`.

After resolving the identifier, navigate directly to its repository path:

```text
manifests/<lowercase-first-character>/<identifier-segment-1>/<identifier-segment-2>/.../<PackageVersion>/
```

Split `PackageIdentifier` at every dot and preserve the casing of each component. Each component is an individual directory; never combine multiple components in a dotted directory name. For example:

```text
Google.Chrome.Canary
`-- manifests/g/Google/Chrome/Canary/<PackageVersion>/
```

`manifests/g/Google.Chrome.Canary/<PackageVersion>/` and `manifests/g/Google/Chrome.Canary/<PackageVersion>/` are invalid. The no-dot rule applies to identifier directories, while the version leaf uses the exact `PackageVersion` and can contain dots.

Do not start with recursive `rg`, `grep`, `Get-ChildItem -Recurse`, or equivalent full-tree searches merely to determine whether a package exists; the winget-pkgs tree is too large for that to be the default discovery method. Use direct file lookup after `winget search`, and use scoped repository searches only for fields or examples that the public source does not expose. Also check open upstream pull requests before submitting a new package because pending packages are not yet returned by `winget search`.

## Define The Package Identifier

Define a new identifier only after `winget search`, direct manifest inspection, and an open-pull-request check establish that the product or variant is not already represented. Preserve an existing identifier during ordinary updates; an identifier is a stable package identity rather than a field to rename when a publisher, brand, or preferred naming convention changes.

### Schema Contract

The WinGet 1.12 manifest schema uses this `PackageIdentifier` pattern:

```text
^[^\.\s\\/:*?"<>|\x01-\x1f]{1,32}(\.[^\.\s\\/:*?"<>|\x01-\x1f]{1,32}){1,7}$
```

Together with `maxLength: 128`, this means:

- An identifier has between two and eight dot-separated components. Two components, normally publisher and product, are the usual shape.
- Every component contains between 1 and 32 characters, and the complete identifier contains no more than 128 characters.
- A component cannot contain a dot, whitespace, slash, backslash, colon, asterisk, question mark, double quote, angle bracket, vertical bar, or control character from U+0001 through U+001F. A dot separates components; it is never part of a component.
- Casing is preserved. Use the same identifier exactly in every manifest file, filename, and repository directory component.

The schema permits more than two components so qualifiers can remain explicit. Do not concatenate a region, release channel, major version, edition, or other identity boundary into the product component.

### Qualifier Components

Use a separate component for each qualifier that defines which product the installer represents:

| Identity group | Concrete package and task examples | Authoring rule |
| --- | --- | --- |
| Base product | `7zip.7zip`, `VideoLAN.VLC` | Prefer the usual publisher and product shape when no supported variant needs another identity component. |
| Region | `Kingsoft.WPSOffice.CN`, `Yealink.YealinkUSBConnect.CN`, `Canva.Canva.CN` | Put a distribution region such as `CN` in its own component. Do not append it to the product name. |
| Release channel | `Google.Chrome.Canary`, `Google.Chrome.Beta`, `Google.Chrome.Dev`, `Brave.Brave.Nightly`, `Vivaldi.Vivaldi.Snapshot` | Put `Canary`, `Beta`, `Dev`, `Nightly`, `Preview`, `Snapshot`, or another publisher-defined channel in its own component. Use the publisher's channel name and spelling. |
| Major release line | `Python.Python.3.12`, `Python.Python.3.13`, `Python.Python.3.14`, `OpenJS.NodeJS.20`, `OpenJS.NodeJS.22`, `PostgreSQL.PostgreSQL.17`, `PostgreSQL.PostgreSQL.18` | Put every retained major or compatibility line in separate numeric components. Python uses separate `3` and `12` components rather than a component containing `3.12`. |
| Edition | `DBeaver.DBeaver.Community`, `DBeaver.DBeaver.Enterprise`, `DBeaver.DBeaver.Ultimate`, `Microsoft.VisualStudio.2022.Community`, `Microsoft.VisualStudio.2022.Professional`, `Microsoft.VisualStudio.2022.Enterprise`, `AMustInEveryOffice.ASAPUtilities.Business`, `AMustInEveryOffice.ASAPUtilities.HomeStudent` | Put `Free`, `Corporate`, `Professional`, `Enterprise`, `Community`, `Business`, `HomeStudent`, or another publisher-defined edition in its own component. Keep multiword edition names as one component when the publisher treats them as one edition. |
| Extension or plugin family | `Microsoft.VisualStudio.Extensions.TypeScript`, `ADInstruments.LabChart.Extension.AudioOutput`, `ADInstruments.LabChart.Extension.CardiacAxis`, `EasternGraphics.pCon-planner.Plugin.Acoustics`, `EasternGraphics.pCon-planner.Plugin.VR-Viewer` | Give related add-ons a category component followed by the add-on name. For a new family, prefer a consistent `Extensions` or `Plugins` category. Preserve an established family's existing singular category. |
| Architecture-specific framework | `Microsoft.VCRedist.2015+.x86`, `Microsoft.VCRedist.2015+.x64`, `Microsoft.VCRedist.2015+.arm64` | Split a dependency framework by architecture when dependents must name the matching independently installed runtime. Do not split an ordinary application merely because one manifest can contain several architecture installers. |
| Installer delivery family | `Zoom.Zoom`, `Zoom.Zoom.EXE`, `Google.Chrome`, `Google.Chrome.EXE`, `Google.Chrome.Beta`, `Google.Chrome.Beta.EXE`, `Google.Chrome.Dev`, `Google.Chrome.Dev.EXE` | Use separate identifiers when installer families expose incompatible package or ARP version schemes, or when one artifact is version-specific and the other is a mutable or otherwise independently maintained installer. Do not split solely because both EXE and MSI files exist. |

These are concrete identifiers, not templates to copy mechanically. Search each publisher and product family first, then preserve the established component order and vocabulary when adding a related package.

### When Major Versions Need Separate Packages

Add the major version as one or more identifier components when evidence shows that supported release lines are separate products. Strong evidence includes:

- Different compatibility or dependency contracts, especially when users and dependent packages must select a specific supported major line. The Python, Node.js, and PostgreSQL identifiers above follow this model.
- Side-by-side installation or separate maintenance of more than one major line.
- Stable major-line ARP identities: different EXE uninstall ProductCodes or uninstall keys, or different MSI UpgradeCodes across concurrently supported lines.
- A publisher requiring a paid upgrade or a different entitlement for the next major release. `TechSmith.Snagit.2025`, `TechSmith.Snagit.2026`, `AceBIT.PasswordDepot.18`, and `AceBIT.PasswordDepot.19` are current examples of separately maintained release identities.

Compare multiple releases within each major line before using registry identity as evidence. An MSI ProductCode commonly changes for every product version, and some EXE uninstall keys also change per release; ordinary per-version churn does not by itself justify a new package identifier. Do not split a rolling product whose major update replaces the previous version under the same compatibility, licensing, and ARP identity model.

### Installer Version Schemes And ARP Ranges

WinGet uses explicit `AppsAndFeaturesEntries.DisplayVersion` values to map an installed ARP version back to a manifest version. For each supported installer type, winget-cli aggregates the lowest and highest declared display versions in one manifest version into an ARP version range. The source index rejects overlapping ARP ranges among versions of the same package. During installed package correlation, WinGet maps a detected `DisplayVersion` to the manifest version whose range contains it.

This mapping becomes ambiguous when two installer families for one application publish incompatible version schemes. For example, the current `Zoom.Zoom` MSI package uses a product/build form such as `7.1.43453`, while `Zoom.Zoom.EXE` uses a display form such as `7.1.5 (43453)`. Keep those delivery families separate so their manifest versions and ARP mappings do not overlap or alternate between incompatible forms. The Google Chrome MSI and EXE families are likewise kept as `Google.Chrome` and `Google.Chrome.EXE`; their Beta and Dev channels preserve the same separation.

Before deciding to split, inspect several historical versions of both installer families and collect `PackageVersion`, installer type, ProductCode, UpgradeCode, and ARP `DisplayVersion`. Keep EXE and MSI in one package when they share a single monotonic package-version scheme and resolve to compatible installed identity. Follow [Choose between EXE and MSI](artifact-selection.md#choose-between-exe-and-msi) when both artifacts are equivalent wrappers for the same installation rather than independent delivery families.

Source grounding:

- [WinGet 1.12 version-manifest schema](https://github.com/microsoft/winget-cli/blob/master/schemas/JSON/manifests/v1.12.0/manifest.version.1.12.0.json)
- [ARP range construction in Manifest.cpp](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/Manifest.cpp)
- [ARP range overlap validation in Interface_1_5.cpp](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/Microsoft/Schema/1_5/Interface_1_5.cpp)
- [Installed-version mapping in CompositeSource.cpp](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerRepositoryCore/CompositeSource.cpp)
