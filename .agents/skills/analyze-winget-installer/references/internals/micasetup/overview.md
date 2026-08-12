# MicaSetup internals

This reference describes MicaSetup's compiled installer structure and runtime evidence. Use the [MicaSetup workflow](../../families/micasetup/workflow.md) for manifest authoring and validation.

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Format identity

MicaSetup v1 and v2 are managed .NET Framework WPF executables. The builder edits or regenerates C# configuration, compiles it into an installer, embeds the application archive and uninstaller in WPF resources, and replaces normal assembly identity with application identity. The installed payload is not physically adjacent to the PE overlay; it is a stream value nested inside a compiled `.resources` container referenced by CLR metadata. v1.0 keeps `MicaSetup.Core.Pack` in a Costura-managed dependency and references it from the outer assembly, while later builds define or reference `MicaSetup.Option` and configure it through `UseOptions`.

The parser identifies `Pack`, `OptionLegacy`, and `OptionModern` configuration models. `IsUninstLower` and user-path preference options distinguish the modern v2 schema. Both late v1 and early v2 releases use the legacy option schema, so `BuilderGeneration` is a structural compatibility generation rather than a release-major claim.

## Container stack

```text
MicaSetup installer.exe
+-- DOS header and PE/COFF image
|   +-- native PE headers and section table
|   +-- IMAGE_COR20_HEADER
|   |   +-- MetadataDirectory -> CLR metadata root
|   |   `-- ResourcesDirectory -> managed resource blob
|   +-- CLR metadata
|   |   +-- #~ tables: Assembly, CustomAttribute, TypeDef, MethodDef, Property, ManifestResource
|   |   +-- #Strings and #US heaps
|   |   +-- MicaSetup.Core.Pack member references or MicaSetup.Option schema
|   |   +-- UsePack/UseOptions and UseElevated calls
|   |   `-- generated option-initializer CIL
|   +-- WPF <assembly>.g.resources
|   |   +-- ResourceManager header
|   |   +-- hash/name-position tables
|   |   +-- UTF-16 resource names
|   |   `-- data records
|   |       +-- resources/setups/publish.7z: Stream
|   |       +-- resources/setups/uninst.exe: Stream
|   |       +-- optional publish.cer, license, icon, image, font, and BAML records
|   |       `-- unsupported custom resource records retained as typed metadata only
|   `-- ordinary Win32 resources and Authenticode data
`-- no format-defining PE overlay

publish.7z
+-- configured main executable
+-- managed assemblies and runtime JSON sidecars
+-- native DLLs and other application binaries
`-- installed data files
```

## PE and CLR linkage

`IMAGE_OPTIONAL_HEADER.DataDirectory[COM_DESCRIPTOR]` points to `IMAGE_COR20_HEADER`. The CLR header's metadata directory identifies the metadata root, while `ResourcesDirectory` identifies the managed resource blob. Section RVAs must be translated through the PE section table before the parser reads either range.

```text
IMAGE_COR20_HEADER
Offset  Size  Field
------  ----  ---------------------------------------------
0x00       4  cb, CLR header size
0x04       2  MajorRuntimeVersion
0x06       2  MinorRuntimeVersion
0x08       8  MetadataDirectory { RVA:u32, Size:u32 }
0x10       4  Flags
0x14       4  EntryPointToken or native RVA
0x18       8  ResourcesDirectory { RVA:u32, Size:u32 }
...            remaining CLR data directories
```

The parser uses `PEReader` and `MetadataReader`; it never loads the target assembly into the host AppDomain. Every caller-owned stream remains open and returns to its original position.

## ManifestResource records

An embedded CLR `ManifestResource` row has a nil `Implementation` handle. Its `Offset` is relative to the start of `IMAGE_COR20_HEADER.ResourcesDirectory`, where a four-byte record length precedes the resource data.

```text
CLR managed resource blob
Offset                       Size  Field
---------------------------  ----  -----------------------------------
ResourcesDirectory + Offset     4  ResourceLength:u32 LE
+ 0x04                    length  ResourceData[ResourceLength]
```

The parser enumerates only embedded resources whose metadata name ends in `.g.resources`, validates each outer length against both the CLR directory and the physical file, and then parses the nested ResourceManager stream.

## `.resources` v1 and v2 layout

All offsets below are relative to the beginning of the nested `.resources` stream. Integer fields are little-endian. Strings in the manager/type headers are BinaryReader strings with a 7-bit encoded UTF-8 byte length; resource names are stored as a 7-bit encoded UTF-16LE byte length followed by UTF-16LE bytes.

```text
Offset  Size                         Field
------  ---------------------------  ------------------------------------------
0x00       4                         Magic:u32 = 0xBEEFCACE
0x04       4                         ResourceManagerHeaderVersion:i32
0x08       4                         BytesToSkip:i32
0x0C       BytesToSkip               reader/set type metadata, skipped bounded
...        4                         RuntimeVersion:i32 = 2
...        4                         ResourceCount:i32
...        4                         TypeCount:i32
...        variable                  user type names
...        0..7                      padding to 8-byte relative alignment
...        ResourceCount * 4         name hashes:i32, not needed for enumeration
...        ResourceCount * 4         name positions:i32
...        4                         DataSectionOffset:i32, stream-relative
...        variable                  name section
...        variable                  data section
```

Each name position is relative to the start of the name section. The following signed data position is relative to the data section.

```text
Name record
+-------------------------------+
| NameByteLength: 7-bit int     |
+-------------------------------+
| UTF-16LE name bytes           |
+-------------------------------+
| DataPosition: i32 LE          | -> data section
+-------------------------------+

Data record for Stream/ByteArray
+-------------------------------+
| TypeCode: 7-bit int           | 32 = ByteArray, 33 = Stream
+-------------------------------+
| Length: i32 LE                |
+-------------------------------+
| Data[Length]                  |
+-------------------------------+
```

MicaSetup's official artifacts store `resources/setups/publish.7z` and `resources/setups/uninst.exe` as v2 `ResourceTypeCode.Stream` values. Dumplings returns absolute physical file offsets that start at the stream data and exclude both the type code and length prefix. Runtime version 1 uses an index into the preceding type-name table instead of a `ResourceTypeCode`; the parser maps its primitive framework types but leaves custom serialized records opaque. Supported primitive records are decoded without invoking `BinaryFormatter` or constructing custom resource types. User-defined resource types retain their declared type name as unsupported metadata and are never deserialized.

## Pack/Option schemas and generated CIL

MicaSetup v1.0 configures `MicaSetup.Core.Pack` through `UsePack(Action<Pack>)`. Costura keeps the Pack implementation in a managed dependency, but the outer generated initializer contains MemberRef calls to its setters. Later releases configure `MicaSetup.Option` through `UseOptions(Action<Option>)`. MakeMica replaces initializer assignments in source and compiles them into a generated method. The parser finds methods containing a dense set of Pack or Option setter calls rather than scanning arbitrary strings.

```text
host-builder call chain
Hosting.CreateBuilder()
  -> UseElevated(bool? requested)
  -> UsePack(Action<Pack>) or UseOptions(Action<Option>)
       -> ldarg Pack/Option
       -> constant/reference/string expression
       -> callvirt Option::set_Property(value)
       -> ... repeated assignments
```

The bounded symbolic evaluator supports literal strings, integers, floating-point values, booleans, null, nullable booleans, local loads/stores, simple arrays, option-property getters, string concatenation, string formatting, and resolvable conditional branches. It records the defining method and CIL offset for every option assignment. Unknown calls, object graphs, cyclic control flow, malformed bodies, and unresolved branches remain explicit evidence rather than being executed.

Only a high-density generated initializer contributes configuration values. Legacy Pack property names are normalized to the shared option names consumed by the PowerShell parser. This prevents MicaSetup's own runtime setters from being mistaken for packaged configuration. `UseElevated` is evaluated separately because it lives in the host-builder chain rather than the configuration lambda.

The parser also observes direct `Microsoft.Win32.Registry.SetValue` calls whose key, value name, value, and optional value kind are all literal. It does not emulate `RegistryKey` object state or arbitrary custom C#; unresolved calls produce warnings and require VM validation.

## Scope and ARP runtime

MicaSetup v1 invokes `UseElevated()` unconditionally. MicaSetup v2 permits a nullable elevation request and also compiles a `RequestExecutionLevel` assembly attribute. The parser treats a resolved `UseElevated` value as primary route evidence and the custom attribute as supporting evidence.

During installation, the v2 runtime enters the built-in ARP path only when `Option.Current.IsCreateRegistryKeys && RuntimeHelper.IsElevated`. Otherwise it writes the extracted file catalog to `Uninst.dat`. This means a resolved `KeyName` alone does not prove a `ProductCode`.

```text
install payload
  |
  +-- elevated && IsCreateRegistryKeys
  |     `-- HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\<KeyName>
  |           +-- DisplayName, DisplayVersion, Publisher
  |           +-- DisplayIcon, InstallLocation, UninstallString
  |           +-- NoModify=1, NoRepair=1
  |           `-- SystemComponent=0|1
  |
  `-- otherwise
        `-- <InstallLocation>\Uninst.dat
```

`IsUseRegistryPreferX86=true` opens `Registry32`, false opens `Registry64`, and null uses `RegistryView.Default`. `SystemComponent=1` keeps the physical HKLM key but hides it from the visible Apps & Features set. The generated uninstaller is `Uninst.exe` by default; v2 can choose lowercase `uninst.exe`.

## Installation paths

v1 selects Program Files or Program Files (x86) from its x86 preference. v2 can choose Program Files, Program Files (x86), local application data Programs, or roaming application data according to scope and path preferences. Dumplings projects these locations as `%ProgramFiles%`, `%ProgramFiles(x86)%`, `%LOCALAPPDATA%`, or `%APPDATA%` expressions rather than expanding them on the analysis host.

Path preferences do not prove installed binary architecture. The parser derives architecture from the configured main executable and adjacent native DLLs in `publish.7z`.

## Payload extraction

The parser creates a bounded substream over the `publish.7z` resource and passes that range to the shared SharpCompress archive infrastructure. It does not buffer the complete WPF resource or installer. A resolved constant `UnpackingPassword` is supplied directly to the archive reader and is never returned, logged, serialized, or included in option values.

Payload enumeration validates entry counts and sizes. Extraction additionally validates aggregate expanded bytes, destination containment, traversal, duplicate paths, and collisions. Architecture/dependency analysis materializes only the configured main executable and a bounded set of adjacent DLL/JSON sidecars in a temporary directory, then removes that directory after analysis.

## System effects

Compiled options can prove desktop, Start menu, and Quick Launch shortcuts; HKCU autorun; PATH modification; firewall allow rules; certificate installation; close-application records; refresh behavior; and uninstaller creation. Some operations are conditional on elevation inside the runtime even when their option is enabled.

MicaSetup permits developers to edit the generated C# and attach custom handlers. Any behavior outside supported option assignments and literal static registry writes is arbitrary managed code. The parser reports the supported static projection and leaves computed custom effects unresolved.

## Command-line behavior

`CommandLineHelper` tokenizes `-`, `--`, and `/` options with `=` or `:` values. A generic parser's existence does not prove that a particular key changes installation behavior. Upstream `/q` and `/a` work is unfinished, so the parser returns only `interactive` and no installer switches unless a compatible fork contains separately proven handling.

## Limits and malformed input

The managed reader bounds resources, methods, decoded instructions, string lengths, switch tables, resource counts, table offsets, and all nested ranges. Archive handling adds entry, output-byte, path, and collision limits. Arithmetic is checked before allocation or seeking. Malformed IL contributes bounded warnings when possible; invalid structural identity or unsafe resource ranges reject the format deterministically.

## Known gaps

- Arbitrary custom C#, dynamically computed option values, custom overlay handlers, and `RegistryKey` object flows are not emulated.
- Close-application object details are unresolved when the generated array initializer cannot be reduced to literals.
- Silent installation is not inferred from unfinished upstream command-line hooks.
- Builder patch versions cannot normally be recovered because packaged application versioning replaces builder assembly versioning.
- Kachina Installer requires an independent parser and route.

## Implementation mapping

- `Modules/PackageModule/Assets/Source/MicaSetup/MicaSetupReader.cs`: bounded CLR metadata, CIL, and `.resources` reader.
- `Modules/PackageModule/Libraries/Installers/MicaSetup.psm1`: MicaSetup semantics, ARP projection, payload analysis, and extraction.
- `Modules/PackageModule/Libraries/Infrastructure/InstallerAnalyzer.psm1`: strict family routing and parser orchestration.
- `Modules/PackageModule/Libraries/WinGet/WinGetAnalysis.psm1`: WinGet generic-EXE projection.

## Representative fixtures

- Official v1.0 demo installer: Costura Pack references, UsePack configuration, and unconditional elevated route.
- Official v1.3 demo installer: legacy Option schema and unconditional elevated route.
- Official v2.0 demo installer: early v2 release with the legacy source-compatible Option schema.
- Official v2.5 demo installer: modern Option schema, request-execution-level attribute, WPF resource streams, and payload sidecars.
- Generated malformed `.resources`, CIL, archive, collision, and traversal fixtures cover bounded failure paths.

## Source references

- [lemutec/MicaSetup](https://github.com/lemutec/MicaSetup)
- [MicaSetup v1 branch](https://github.com/lemutec/MicaSetup/tree/v1)
- [MicaSetup v2 branch](https://github.com/lemutec/MicaSetup/tree/v2)
- [MicaSetup option schema](https://github.com/lemutec/MicaSetup/blob/v2/build/MicaSetup/Option.cs)
- [MicaSetup v1.0 Pack schema](https://github.com/lemutec/MicaSetup/blob/v1.0.0/src/MicaSetup.Core/Pack.cs)
- [MicaSetup v1.0 UsePack host](https://github.com/lemutec/MicaSetup/blob/v1.0.0/src/MicaSetup/Program.cs)
- [MicaSetup generated host](https://github.com/lemutec/MicaSetup/blob/v2/build/MicaSetup/Program.cs)
- [MicaSetup install runtime](https://github.com/lemutec/MicaSetup/blob/v2/build/MicaSetup/Helper/Setup/InstallHelper.cs)
- [MicaSetup uninstall registry helper](https://github.com/lemutec/MicaSetup/blob/v2/build/MicaSetup/Helper/System/RegistyUninstallHelper.cs)
- [MicaSetup command-line parser](https://github.com/lemutec/MicaSetup/blob/v2/build/MicaSetup/Helper/CommandLineHelper.cs)
- [.NET `ResourceReader`](https://github.com/dotnet/runtime/blob/main/src/libraries/System.Private.CoreLib/src/System/Resources/ResourceReader.cs)
- [ECMA-335 standard](https://ecma-international.org/publications-and-standards/standards/ecma-335/)
