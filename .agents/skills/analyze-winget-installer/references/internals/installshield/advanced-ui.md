# InstallShield Advanced UI internals

[Back to InstallShield parser internals](overview.md).

## Binary structure

Advanced UI and Suite/Advanced UI append a structured bootstrap catalog. The outer suite owns its own ARP entry; nested MSI ProductCodes describe parcels and must not replace `SuiteId` in the outer manifest.

```text
Extracted Advanced UI media
+-- Setup.xml (namespace installshield/<year>/bootstrap)
|   +-- Setup/@SuiteId                 outer ARP ProductCode
|   +-- ARPInfo                        version/publisher/name/icon/URLs
|   +-- LanguageSelection + Languages localized string table
|   +-- SetProperty[@Name=INSTALLDIR]  authored install-root expression
|   `-- Parcels (ordered)
|       +-- Msi/Msp/Exe/Isp/...        package type and identity attributes
|       +-- UIProperties/Id            selection/detection identity
|       +-- Package/Folder/File        exact staged path, URL, size, MD5
|       +-- Operation                  target executable and operation name
|       |   +-- CommandLine            interactive arguments
|       |   `-- Silent                 unattended arguments
|       +-- Property                   elevation/reboot/upgrade behavior
|       `-- Detect/When                package-presence conditions
+-- Setup_UI.xml / Setup_UI.dll        suite user interface
+-- Setup.inx                          suite runtime script, not proof of InstallScript MSI
|   `-- roots named by Actions/CallInstallScript/@Arguments
`-- {parcel-id}/payload.msi|exe         embedded package files
```

## Parsing behavior

Parse `Setup.xml` once, preserve parcel order, and select nested payloads from authored `Package`, `Folder`, `File`, and `Operation` records. Treat `Setup.inx` as suite runtime evidence only when an authored action calls it.

## Metadata projection

The outer suite owns the visible ARP entry. Project `SuiteId`, `ARPInfo`, localized strings, install-root expressions, operation arguments, and parcel conditions separately. Nested MSI ProductCodes identify parcels and must not replace the suite ProductCode.

## Limits and gaps

Reject unresolved parcel paths, invalid sizes or hashes, and unsupported conditions. Dynamic suite UI, downloads, and script branches remain conditional evidence until static records or VM validation resolve them.
