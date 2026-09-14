# Wise metadata model

## Evidence layers

Wise metadata can originate in the outer PE or NE host, an embedded WSE source listing, compiled WiseScript state records, a nested Wise launcher, or a nested MSI database. These layers describe different objects. The parser keeps them separate and chooses the narrowest authoritative source for each returned field.

| Output | Preferred evidence | Safe fallback |
| --- | --- | --- |
| `DisplayName` | nested MSI `ProductName` | WSE `Title`, then outer PE product identity |
| `DisplayVersion` | nested MSI `ProductVersion` | WSE `Version` |
| `Publisher` | nested MSI `Manufacturer` | outer PE `CompanyName` |
| `ProductCode` | nested MSI `ProductCode` | none; a custom WiseScript uninstall suffix is candidate evidence until its branch is proven |
| `UpgradeCode` | nested MSI `UpgradeCode` | none |
| `Scope` | explicit nested MSI scope evidence | none; requested elevation does not by itself prove the ARP hive |
| `DefaultInstallLocation` | nested MSI directory resolution | none |
| `Protocols` and `FileExtensions` | nested MSI registry and extension tables | none; unexecuted WiseScript associations remain evidence only |

## WSE source member

Some Wise 9 media contains an `INSTALL_SCRIPT` Deflate member whose decompressed text begins with `Document Type: WSE`. The parser reads only the `item: Global` block and its literal `name=value` properties. It currently uses `Version`, `Title`, `Requested Execution Level`, and numbered variable definitions. It does not interpret arbitrary WSE statements as a source program.

Variable declarations use paired keys such as `Variable Name1` and `Variable Default1`. Dumplings stores these in a case-insensitive dictionary. A missing default is represented as an empty string rather than guessed from a runtime environment.

## Compiled state model

The decompressed `WiseScript.bin` member contains a header and an ordered state sequence. Dumplings projects four state families that affect package analysis:

| State | Evidence returned |
| --- | --- |
| `InstallFile` | payload offsets, compressed and inflated sizes, CRC32, and destination expression |
| `EditRegistry` | root and flags, data type, key, value name, and value expression |
| `ExecuteProgram` | executable path, arguments, working directory, and flags |
| `CallDllFunction` | deterministic variable assignments for compiler-generated `f16` records; other DLL calls remain opaque |

The parser also returns operation counts so an analyst can see which unprojected state families exist. A state record proves that an operation is compiled into the package. It does not prove that surrounding conditionals select the operation during a particular installation.

## Variable substitution

`Resolve-WiseVariableText` performs bounded, case-insensitive replacement of `%NAME%` references using only literal variables recovered from WSE metadata or deterministic compiler-generated assignment records. Resolution stops after 16 passes. Unknown references remain visible in the returned expression. Self-referential values are not expanded recursively.

Known runtime variables such as `%MAINDIR%`, `%TEMP%`, `%WORKINGDIR%`, and `%SYSTEM%` are not assigned host values during static parsing. Replacing them with paths from the analysis computer would fabricate installation behavior.

## Payload catalog

Every projected `InstallFile` state becomes one `PayloadCatalog` entry. `DeflateStart` and `DeflateEnd` are relative to the payload-data base selected by the Wise overlay header. `ResolvedDestinationPath` means that known project variables were substituted; it may still contain runtime variables and therefore is not necessarily a usable host path.

Several records can target the same path because Wise projects can install language-specific or condition-specific alternatives. The catalog preserves every record in source order. Extraction collision policy decides how physical outputs are named; it does not resolve runtime conditions.

## Nested payload authority

For a WiseScript package, Dumplings examines at most 16 file records whose destination ends in `.exe`. Each candidate is decompressed and checked as a PE. A nested executable becomes MSI authority only when it contains a bounded `.WISE` record with a valid MSI CFB root CLSID and matching CRC32. Filename, PE description, and CFB magic alone are insufficient.

When this route succeeds, `EmbeddedMsiPayloadRecord` identifies the exact WiseScript file action, `EmbeddedMsi` identifies the exact MSI byte range inside that payload, and MSI tables supply the returned product metadata. The outer WiseScript remains authoritative for wrapper installability and elevation behavior.
