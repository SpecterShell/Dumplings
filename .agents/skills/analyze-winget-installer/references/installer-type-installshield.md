# InstallShield Installer Type

Switch documentation: [InstallShield setup.exe command-line parameters](https://docs.revenera.com/installshield26helplib/helplibrary/IHelpSetup_EXECmdLine.htm).

## When To Use

Use `InstallerType: exe # InstallShield` when WinGet invokes an InstallShield EXE wrapper. Direct InstallShield-authored MSI packages are covered in `installer-type-msi-wix.md`.

InstallShield Advanced UI is a separate EXE family with different switches. Do not apply Basic MSI switches to Advanced UI unless package-specific evidence proves they work.

## Detection

Route here when `Get-InstallShieldInfo` succeeds, static strings contain `InstallShield`, `ISSetup.dll`, `InstallScript`, `setup.inx`, or package history strongly suggests InstallShield.

Classify the variant before writing manifest fields. The presence of an MSI is
not sufficient by itself because Advanced UI and Suite/Advanced UI can carry MSI
parcels:

- Basic MSI: the selected MSI is InstallShield-authored but lacks the
  InstallScript MSI runtime verifier/tables. A Basic MSI may still contain
  individual compiled InstallScript custom actions in `Binary.ISSetup.dll`;
  those actions do not change the project type.
- InstallScript MSI: the selected MSI contains `ISInstallScriptAction`,
  `ISScriptFile`, `ISInstallScript*`, or `ISVerifyScriptingRuntime` evidence.
- InstallScript-only: no MSI payload; often requires response-file replay.
- Advanced UI or Suite/Advanced UI: extracted `Setup.xml` uses the
  `installshield/<year>/bootstrap` namespace and contains `ARPInfo`/`Parcels`.

Block InstallScript-only installers when silent installation requires a response file, because response-file replay is not accepted by winget-pkgs validation.

## Binary Structure

InstallShield has several incompatible generations. Dumplings first separates the PE launcher from its overlay, then decodes only the supported stream/catalog variants. A nested MSI is selected from decoded metadata rather than from a recursive `*.msi` wildcard. Older Basic MSI media can instead keep `Setup.ini` and the MSI beside `setup.exe`; that sibling relationship is metadata, not an embedded overlay.

```text
PE setup launcher
+-- overlay
|   +-- PackageForTheWeb preamble
|   |   `-- Microsoft Cabinet extending exactly to end of file
|   |       +-- Setup.exe / Setup.ini / setup.inx
|   |       `-- data*.cab and project media
|   +-- optional "NB10" debug prefix
|   +-- encoded stream form
|   |   +-- "InstallShield" or "ISSetupStream" header (46 bytes)
|   |   +-- repeated old (0x138-byte) or stream attributes
|   |   `-- transformed/zlib payload ranges
|   `-- plain form
|       +-- ANSI or UTF-16 record headers
|       `-- adjacent bounded file ranges
`-- optional legacy external media
    +-- Setup.ini
    |   +-- [Startup] PackageName -> package section
    |   `-- [PackageName] Location -> exact media-relative MSI path
    `-- selected sibling MSI
```

PackageForTheWeb is a distinct outer generation. Dumplings searches only the
bounded PE overlay, requires a complete Cabinet 1.3 header whose declared size
ends at installer EOF, and then uses its bounded cabinet API to enumerate or
extract only selected entries. An incidental `MSCF` string is not sufficient.

```text
Embedded PackageForTheWeb Cabinet (absolute installer offsets)
Offset  Size  Field
------  ----  --------------------------------------------------
+0x00      4  Magic: 4D 53 43 46 ("MSCF")
+0x08      4  Cabinet length, uint32 LE; candidate + length = EOF
+0x10      4  CFFILE table offset, uint32 LE
+0x18      2  Version 1.3 (minor byte, major byte)
+0x1A      2  Folder count, uint16 LE
+0x1C      2  File count, uint16 LE; bounded to 4096
+0x1E      2  Flags; previous/next-cabinet bits must be clear
...           CFFOLDER and compressed CFDATA blocks
...           CFFILE catalog, including media-root-relative names
```

```text
Decoded stream header (record-relative)
Offset  Size      Field
------  --------  ---------------------------------------------
0x00    14        NUL-padded ASCII "InstallShield"/"ISSetupStream"
0x0E    2         FileCount, uint16 LE
0x10    4         AttributeType, uint32 LE (supported: 0..4)
0x14    26        Reserved/observed header bytes

Legacy attribute (0x138 bytes)
0x00    260       NUL-terminated file name bytes
0x104   4         EncodedFlags, uint32 LE
0x10C   4         FileLength, uint32 LE
0x118   2         Unicode-launcher evidence, uint16 LE
0x138   FileLen   adjacent encoded file payload

ISSetupStream attribute
0x00    4         FileNameLength, uint32 LE
0x04    4         EncodedFlags, uint32 LE
0x0A    4         FileLength, uint32 LE
0x16    2         Unicode-launcher evidence, uint16 LE
0x18    24        optional extra record when AttributeType == 4
...     N         UTF-16LE file name
...     FileLen   adjacent encoded file payload
```

The payload transform is applied only to the declared file range; a valid decoded zlib prefix is checked before decompression. Header count, name length, file length, next-record position, safe output path, and decoded output are bounded. Basic MSI, InstallScript MSI, InstallScript-only, and Advanced UI classification depends on the decoded catalog and nested payload evidence, not on a shared marker alone.

Advanced UI and Suite/Advanced UI append a structured bootstrap catalog. The
outer suite owns its own ARP entry; nested MSI ProductCodes describe parcels and
must not replace `SuiteId` in the outer manifest.

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

Basic MSI and InstallScript MSI projects can also compile authored
InstallScript custom actions into the MSI `Binary` table. The physical payload
and dispatch metadata are separate: `CustomAction.Target` is commonly an opaque
`fN` export, while `IsConfig.ini` supplies the authored function name.

```text
MSI database
+-- Binary.Name = "ISSetup.dll"
|   `-- PE image
|       `-- overlay: "ISSetupStream"
|           +-- Setup.inx              compiled InstallScript bytecode
|           +-- IsConfig.ini
|           |   `-- [fN] Function=<authored function name>
|           +-- StringLLLL.txt         localized __LoadString resources
|           `-- InstallScript runtime support files
`-- CustomAction
    +-- Source = "ISSetup.dll"
    +-- Target = "fN"
    `-- Action + sequence tables        invocation and condition evidence

Resolution chain
CustomAction.Target "f1" -> IsConfig.ini [f1].Function
                         -> bounded emulation of only that Setup.inx function
```

`ISVerifyScriptingRuntime`, `ISInstallScriptAction`, `ISScriptFile`, and the
`ISInstallScript*` table/action families classify an InstallScript MSI.
`Source=ISSetup.dll` plus an `fN` target proves a compiled custom action but does
not by itself distinguish Basic MSI from InstallScript MSI.

Some script-driven media stores `setup.inx` inside InstallShield's proprietary
cabinet format rather than in the outer launcher catalog. Dumplings enumerates
that catalog but extracts only InstallScript support files; the application
payload remains compressed.

```text
data1.hdr
+-- CommonHeader (20 bytes)
|   +-- 0x00  4  Magic: 49 53 63 28 ("ISc(")
|   +-- 0x04  4  Version, uint32 LE
|   +-- 0x0C  4  CabinetDescriptorOffset, uint32 LE
|   `-- 0x10  4  CabinetDescriptorSize, uint32 LE
`-- CabinetDescriptor
    +-- directory/file counts and relative table offsets
    +-- directory and file-name strings (UTF-16LE for modern media)
    +-- descriptor+0x30 -> locale-specific setup-type records
    +-- descriptor+0x3E -> 71 file-group hash buckets
    +-- descriptor+0x15A -> 71 component hash buckets
    +-- descriptor+0x27E -> shell-object table directory
    +-- descriptor+0x282 -> registry-set directory
    `-- repeated 0x57-byte file descriptors
        +-- flags, expanded/compressed sizes, and data offset
        +-- MD5, name offset, directory index, and volume number
        `-- split/link metadata

dataN.cab
+-- CommonHeader (20 bytes)
+-- VolumeHeader (64 bytes for InstallShield 6+)
`-- selected file range
    `-- repeated uint16-LE compressed length + raw Deflate block
```

The focused reader rejects old pre-v6 catalogs, missing volumes, invalid ranges,
oversized output, malformed Deflate chunks, expanded-size mismatches, and MD5
mismatches. Split files are read as one bounded stream over the first/last-file
ranges in consecutive volume headers, including when Deflate framing crosses a
volume boundary. Linked descriptors resolve through `LinkPrevious` with index,
flag, depth, and cycle validation; `LinkNext` is retained as the forward alias
relationship. `Get-InstallShieldInfo` exposes
`InstallShieldCabinetSupport` with catalog counts and selected support-file
evidence without returning every application-file record.

Modern InstallScript media stores project-authored registry sets and shell
objects in descriptor-relative pointer graphs. The parser reads these records
from the same bounded `data*.hdr` allocation used for the file catalog.

```text
descriptor+0x282 -> RegistryDirectory
+0x00  uint16  registry-set count
+0x02  uint32  registry-set offset table, descriptor-relative
  `-> RegistrySet (40 bytes)
      +0x00 uint32 qualified name, usually ProductGUID:SetName
      +0x04 uint16 component count
      +0x06 uint32 component-name offset table
      `+0x0A five 6-byte root slots: HKCR, HKCU, HKLM, HKU, SHCTX
          `-> KeyRecord (14 bytes) -> ValueRecord (10 bytes)
              +0x00 uint32 value-name pointer
              +0x04 uint16 REGDB type
              `+0x06 uint32 encoded-data string pointer

REGDB payload encodings used by current media
+-- REGDB_STRING / REGDB_STRING_EXPAND -> direct media string
+-- REGDB_BINARY -> hexadecimal byte string
+-- REGDB_NUMBER -> invariant decimal uint32 text
`-- REGDB_STRING_MULTI -> hexadecimal MULTI_SZ bytes

descriptor+0x30 -> SetupTypeLocaleGroup[]
  `-> SetupType -> included feature-path strings

descriptor+0x3E / +0x15A -> 71 OffsetList hash buckets
+-- FileGroup -> project Component name + first/last cabinet file index
`-- Component -> feature path + included FileGroup names

descriptor+0x27E -> media-table offset array
  `-> entry 2 -> shell-folder group
      `-> ShellFolder (20 bytes)
          `-> packed ShortcutRecord (54 bytes)
              +-- Name / ISShortcutName
              +-- Target / Arguments / WorkingDirectory
              +-- generated properties (`HotKeyCode=...`) / ShowCmd
              `-- owning component
```

`<Default>` is created during normal file transfer. Unassociated named registry
sets are promoted only when a complete literal `CreateRegistrySet` call selects
that name or the empty-string all-sets form. Component-associated registry sets
are instead created when their selected component transfers, so they remain in
`ConditionalMediaRegistryWrites` with component, feature-path, and eligible
setup-type evidence. `CreateShellObjects`
similarly applies only to unassociated shortcuts; component-associated records
are created by component transfer and remain in `ConditionalMediaShortcuts`
until feature/component selection is known. The parser decodes the five
documented REGDB value types, shortcut hotkeys, and show state. Other shortcut
bytes stay unresolved rather than being guessed.

InstallScript-only media adds a project configuration and a compiled script. The parser decodes modern INX catalogs and instructions into a bounded structural IR and abstractly interprets source-backed language operations. Imported DLLs, registry APIs, payloads, and child processes are never invoked: calls are recorded as static evidence and only documented effects are projected.

```text
Extracted InstallScript media
+-- setup.ini
|   `-- [Startup]
|       +-- ProductGUID  -> PRODUCT_GUID and default uninstall-key name
|       +-- Product      -> IFX_PRODUCT_NAME default
|       +-- AppName      -> older PackageForTheWeb project-name fallback
|       `-- CompanyName  -> IFX_COMPANY_NAME default
+-- setup.inx / setup.ins
|   +-- CRC/version prefix
|   +-- copyright marker within the first 512 decoded bytes
|   `-- bounded instruction and call evidence
|       +-- arithmetic, comparison, string, branch, RESULT, and member state
|       +-- RegDBSetItem / RegDBSetKeyValueEx / generated registry wrappers
|       +-- process, file, and shortcut API arguments
|       `-- Software\Microsoft\Windows\CurrentVersion\Uninstall\
+-- StringTable_0xLLLL.ips
|   `-- localized key/value resources used by __LoadString wrappers
`-- optional setup.iss
    `-- silent dialog responses; not authoritative ARP version metadata

MaintenanceStart default projection
+-- HKCU or HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\{ProductGUID}
|   +-- ProductGuid      = PRODUCT_GUID
|   +-- DisplayName      = IFX_PRODUCT_NAME
|   +-- DisplayVersion   = IFX_PRODUCT_VERSION       (runtime; unresolved)
|   +-- Publisher        = IFX_COMPANY_NAME
|   +-- InstallLocation  = TARGETDIR                 (runtime; unresolved)
|   `-- UninstallString  = UNINSTALL_STRING          (runtime; unresolved)
`-- visibility/scope depend on ALLUSERS and ADDREMOVE_SYSTEMCOMPONENT
```

```text
Modern or Stirling-era decoded setup.inx
Offset  Size      Field
------  --------  --------------------------------------------------------
0x00    4         CRC/signature-like value; decoded files commonly use aLuZ
0x04    2         compiler/header value, uint16 LE
0x06    74        NUL-padded InstallShield/Stirling copyright field, ASCII
0x50    24        reserved/observed header data
0x68    20        five absolute uint32 LE offsets
                    offset[2] -> type/function/label catalog
                    offset[4] -> end of instruction segment

Catalog at offset[2]
+-- uint16 TypeCount
|   `-- repeated type-field records
+-- uint16 FunctionCount
|   `-- type, return type, DLL/name strings, entry label, parameters
+-- uint16 LabelCount
|   `-- repeated uint32 absolute instruction offsets
`-- function bodies
    +-- observed uint16 body prefix
    +-- 0x0022 function-start record
    +-- tagged, variable-length instruction records
    `-- 0x0026 function-end record

Call instruction 0x0020/0x0021
+-- uint16 FunctionPrototypeIndex
+-- uint16 ArgumentCount
`-- repeated tagged operands
    +-- 0x00: byte integer
    +-- 0x06: uint16 length + ASCII string
    +-- 0x07: int32 LE
    `-- 0x02..0x0A: variable, local, or label references

Property proxy registration 0x003B (official 11.5 compiler observation)
+-- uint16 EncodedCount = 3 (destination plus two operands)
+-- tagged destination: runtime-backed variable
+-- tagged int32 GetterFunctionIndex
`-- tagged int32 SetterFunctionIndex
    `-- normally followed by numeric-slot = RESULT, storing the opaque handle
```

The reader validates every catalog count, offset, string, operand, instruction count, and function boundary. Modern core and extension records are structurally decoded through their tagged operand framing. The abstract interpreter evaluates source-backed arithmetic, comparisons, string operations, RESULT-slot operations, generated wrappers, and structure-member state. InstallShield 11.5 differential builds ground `AddressOf`, primitive `Indirect`, pointer-parameter prologues, and prototype flag `0x02` (`BYREF`): referenced structure snapshots survive function-frame changes, primitive references can be read without creating a host pointer, and callee assignments are written back to the caller. The same official compiler output grounds `Handler(eventId, functionIndex)`, `ExecuteHandler(eventId)`, and inline `try`/`catch`/`endcatch` framing. Normal-path analysis skips exception-only catch bodies; imported calls are not executed, so catch-only effects remain conditional rather than being promoted to ARP evidence. `UseDLL` and `UnUseDLL` produce `DllOperations` containing the requested module path, but the DLL is never loaded and its exported functions remain opaque. Official 11.5 compiler output also grounds opcode `0x003B` as a runtime property-proxy registration: `PropertyHandlers` exposes the target variable, paired getter/setter functions, and compiler-generated handle slot. The parser does not invoke those handlers or guess their process-dependent initial values. It intentionally does not call `0x003B` `AskOptions`; historical decompilers disagree on that label. Other unknown extension semantics remain in `UnsupportedOpcodes` and are never assigned invented behavior. Limits bound recursion, loops, paths, calls, instructions, value alternatives, and emitted effects. `Get-InstallShieldInstallScriptDialogTrace` follows entry-point calls and generated wrapper literals, grouping `OnFirstUIBefore` with `OnFirstUIAfter` and maintenance equivalents. Mutually exclusive license/completion dialogs remain alternatives rather than being flattened into an invented sequence.

Direct `RegDBSetKeyValueEx`, legacy registry setters, and compiler-generated `_RegSetKeyValue` wrappers produce `RegistryWrites`. Complete HKCR writes are converted to `Protocols`, `FileExtensions`, `ProtocolAssociations`, and `FileExtensionAssociations`; localized `.ips` resources are resolved before association matching. `RegDBSetItem` produces `RegistryItems` and can override built-in `DisplayName`, `DisplayVersion`, `Publisher`, `InstallLocation`, `ProductGuid`, and `SystemComponent` before `MaintenanceStart`. `CreateProcess`, `LaunchApp*`, `ShellExecute*`, file APIs, and shortcut APIs produce typed evidence without performing the operation. `CreateRegistrySet` and `CreateShellObjects` select the independently parsed media-database records described above. Selection and records are reported separately so conditional project data is not mistaken for an executed effect.

Older generated scripts may expose only a `program` entry point which delegates
to `ISRT._ShowWizardPages`. Official InstallShield framework source shows that
the runtime calls the exported `IfxOnShowWizardPages` function, which then
selects first-install, maintenance, or update UI. Dumplings follows that callback
back into ordinary INX functions, preserves nested call order, and reports the
result as `DialogTraces.Source: FrameworkCallback`. It does not treat the runtime
function as an opaque data table.

Framework reconstruction still remains incomplete when `MODE`, `MAINTENANCE`,
feature selection, or BACK/NEXT branches can suppress, repeat, or replace pages.
Completion choices such as `SdFinish` versus `SdFinishReboot` remain alternatives,
and the generated response template requires review against a VM-recorded file.
The Unitronics U90 Ladder 6.6.45 PackageForTheWeb/Stirling fixture exercises this
path: its fresh-install sequence exposes `SdWelcome`, `SdLicense`,
`SdAskDestPath`, `SdSelectFolder`, and `SdStartCopy`, while maintenance exposes
`SdWelcomeMaint` and `SdComponentTree`. The SHARP Pen Software 3.9 sample is
MSI-bearing InstallShield media and does not add a distinct InstallScript behavior
to the focused fixture set.

For scrambled INX generations, each byte is decoded from its absolute file offset as `ROR8(encoded XOR 0xF1, 2) - (offset modulo 71)`. The parser validates the copyright marker in the decoded header before accepting the transform. It reports only documented default ARP values and labels custom script assignments as unresolved.

## Manifest Shape

Use this only when MSI extraction/metadata and silent behavior are verified:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallShield
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  - silentWithProgress
  InstallerSwitches:
    Silent: /S /V/quiet /V/norestart
    SilentWithProgress: /S /V/passive /V/norestart
    InstallLocation: /V"INSTALLDIR=""<INSTALLPATH>"""
    Log: /V"/log ""<LOGPATH>"""
  ProductCode: <ProductCode>
  AppsAndFeaturesEntries:
  - UpgradeCode: <UpgradeCode>
    InstallerType: msi
```

Known MSI-backed InstallShield examples:

- `Zultys.ZAC`
- `Robomatter.ROBOTC.LEGOMindstorms`
- `Robomatter.ROBOTC.VEXRobotics`
- `Robomatter.RobotVirtualWorlds.ChallengePack`
- `Robomatter.RobotVirtualWorlds.CurriculumCompanion`
- `Robomatter.RobotVirtualWorlds.FTCCascadeEffect`
- `Robomatter.RobotVirtualWorlds.LevelBuilder`
- `Robomatter.RobotVirtualWorlds.MiniUrbanChallenge`
- `Robomatter.RobotVirtualWorlds.OperationReset`
- `Robomatter.RobotVirtualWorlds.PalmIslandLuauEdition`
- `Robomatter.RobotVirtualWorlds.RuinsOfAtlantis`
- `Robomatter.RobotVirtualWorlds.VEXIQHighrise`
- `Robomatter.RobotVirtualWorlds.VEXIQNextLevel`
- `Robomatter.RobotVirtualWorlds.VRCTurningPoint`
- `Abbott.LibreViewDeviceDrivers`
- `Sonos.Controller`
- `Sonos.S1Controller`
- `LANCOM.LANconfig`
- `LANCOM.LANmonitor`
- `LANCOM.TrustedAccessClient`
- `LANCOM.WirelessePaperServer`
- `Thorlabs.APT.x64`
- `Thorlabs.APT.x86`
- `Thorlabs.ELLO`
- `Thorlabs.Kinesis.x64`
- `Thorlabs.Kinesis.x86`
- `Thorlabs.MC2000`
- `Thorlabs.MCLS2`
- `Thorlabs.PCD1K`
- `Thorlabs.SA201B`
- `Thorlabs.SC30`
- `Thorlabs.ThorAOControl`
- `Thorlabs.ThorlabsDeviceSDK`
- `Thorlabs.TSP01`
- `Thorlabs.XA`
- `Thorlabs.xPlatform`
- `BioSilico.IdeaMapper`
- `BioSilico.IdeaMapper.HigherEd`
- `BioSilico.IdeaMapper.K12`
- `BioSilico.IdeaMapper.Pro`
- `Mitel.MitelConnect`
- `MindGenius.MindGenius.20`
- `Pathloss.AntRad`
- `DYMO.DYMOConnect`
- `DYMO.DYMOID`
- `DYMO.DYMOLabel`
- `DYMO.PrintServerControlCenter`
- `NWEA.NWEASecureTestingBrowser`

## Manifest Shape: InstallShield InstallScript

Use this shape only when `Get-InstallShieldInfo` reports `HasMsi: false`, `HasInstallScript: true`, and `Variant: InstallScript`. The absence of an MSI means the InstallScript engine owns installation and ARP behavior; do not apply Basic MSI `/V...` forwarding switches or derive ProductCode/UpgradeCode from a nonexistent nested database.

Most InstallScript installers require recording and replaying a caller-supplied `setup.iss` response file for unattended installation. That additional package-specific input is not supported by winget-pkgs validation. A valid `setup.iss` already shipped beside `setup.inx` is different: InstallShield's default `/s` lookup can consume it without an additional manifest payload.

`Celsys.ClipStudioPaint` is self-contained rather than response-free: its installer embeds a valid `setup.iss` with the dialog order and responses, so `/s` needs no caller-supplied file.

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallShield InstallScript
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  InstallerSwitches:
    Silent: /s
  ProductCode: <VerifiedInstallScriptUninstallKey>
```

Known InstallShield InstallScript package:

- `Celsys.ClipStudioPaint`

The rejected `IndexEducation.PronoteClient` submission in
[winget-pkgs#112792](https://github.com/microsoft/winget-pkgs/pull/112792)
is a useful response-file-dependent example. Its x86 and x64 installers use
different ProductGUID values and store a scrambled `setup.inx` inside
`data1.hdr/data1.cab`; both require an external `setup.iss`.

## Manifest Shape: InstallShield Advanced UI

Use this only for InstallShield Advanced UI packages that accept these switches:

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallShield Advanced UI
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallerSwitches:
    Silent: /silent
    SilentWithProgress: /passive
    InstallLocation: /INSTALLDIR="<INSTALLPATH>"
  ExpectedReturnCodes:
  - InstallerReturnCode: 0x8004070b
    ReturnResponse: invalidParameter
  - InstallerReturnCode: 0x80040711
    ReturnResponse: installInProgress
  - InstallerReturnCode: 1601
    ReturnResponse: contactSupport
  - InstallerReturnCode: 1602
    ReturnResponse: cancelledByUser
  - InstallerReturnCode: 1618
    ReturnResponse: installInProgress
  - InstallerReturnCode: 1623
    ReturnResponse: systemNotSupported
  - InstallerReturnCode: 1625
    ReturnResponse: blockedByPolicy
  - InstallerReturnCode: 1628
    ReturnResponse: invalidParameter
  - InstallerReturnCode: 1633
    ReturnResponse: systemNotSupported
  - InstallerReturnCode: 1638
    ReturnResponse: alreadyInstalled
  - InstallerReturnCode: 1639
    ReturnResponse: invalidParameter
  - InstallerReturnCode: 1641
    ReturnResponse: rebootInitiated
  - InstallerReturnCode: 1640
    ReturnResponse: blockedByPolicy
  - InstallerReturnCode: 1643
    ReturnResponse: blockedByPolicy
  - InstallerReturnCode: 1644
    ReturnResponse: blockedByPolicy
  - InstallerReturnCode: 1649
    ReturnResponse: blockedByPolicy
  - InstallerReturnCode: 1650
    ReturnResponse: invalidParameter
  - InstallerReturnCode: 1654
    ReturnResponse: systemNotSupported
  - InstallerReturnCode: 3010
    ReturnResponse: rebootRequiredToFinish
  ProductCode: <ProductCode>
```

Known Advanced UI examples:
- `Trimble.SketchUp.*`
- `Trimble.SketchUpViewer`.

## WinGet Defaults And Overrides

WinGet supplies no InstallShield-specific defaults for outer `InstallerType: exe`. Treat each shown switch as a complete override for the proven InstallShield variant. Preserve no-reboot arguments in silent modes, and do not apply Basic MSI forwarding switches to InstallScript-only or Advanced UI packages.

## Step-By-Step Analysis

### Step 1: Classify And Parse The InstallShield Variant

Use `Modules\PackageModule\Libraries\InstallShield.psm1` to extract and classify InstallShield payloads without running the installer or shelling out to `ISx.exe`. The module contains an in-process parser based on the ISx container format; see the [ISx source repository](https://github.com/lifenjoiner/ISx). ISx is format attribution only: Dumplings neither distributes nor requires the ISx executable.

```powershell
. .\Modules\PackageModule\Index.ps1

$Info = Get-InstallShieldInfo -Path $InstallerFile
if ($Info.Variant -eq 'Advanced UI') {
  $Info.AdvancedUiInfo
  $Info.SuitePackages
} elseif ($Info.HasMsi) {
  $MsiInfo = Get-InstallShieldMsiInfo -Installer $Info
  $Info.MsiPayloadSelection
  $MsiInfo.SelectedMsiPath
} elseif ($Info.HasInstallScript) {
  $Info.InstallScriptInfo
}
```

Use `Expand-InstallShieldInstaller` when file-level inspection is needed:

```powershell
$OutputDirectory = Join-Path $env:TEMP 'InstallShieldExtract'
Expand-InstallShieldInstaller -Path $InstallerFile -DestinationPath $OutputDirectory -CollisionAction Rename
```

When an extracted `data*.hdr` owns the application payload, use the managed
cabinet extractor. Omit `-Name` to extract every valid entry; use `-Name` only
for a reviewed wildcard selection. Parser-internal callers use `Rename` so
duplicate catalog paths do not overwrite one another.

```powershell
$CabinetOutput = Expand-InstallShieldCabinet `
  -Path $Info.InstallShieldCabinetSupport.HeaderFiles[0] `
  -DestinationPath (Join-Path $env:TEMP 'InstallShieldCabinet') `
  -CollisionAction Rename
```

`Get-InstallShieldInfo` returns `Variant`, `HasMsi`, `HasInstallScript`, extracted MSI paths, InstallScript `.inx`/`.ins` paths, CAB/HDR paths, and extracted `*_sfx.exe` launchers. For Basic MSI and InstallScript MSI wrappers, it parses `Setup.ini`, reads `[Startup] PackageName` and the matching package section's `Location`, and exposes the exact path as `MsiPayloadSelection.SelectedMsiPath`. The configuration can be embedded or, for legacy media, beside `setup.exe`; `MsiPayloadSelection.SourceKind: ExternalSibling` identifies the latter. External-media resolution accepts only that safe, exact `.msi` path and never scans the sibling directory. `Get-InstallShieldMsiInfo` reads the selected MSI instead of taking the first `*.msi` match. `Get-MsiInstallerInfo` reports `InstallShieldProjectType` and its exact table/custom-action evidence.

For Advanced UI media, reuse `$Info.AdvancedUiInfo` and
`$Info.SuitePackages`. The former resolves `SuiteId`, ARP metadata, scope, and
`INSTALLDIR`; the latter records every parcel's type, ID, identity attributes,
file path/URL, operation targets, normal/silent arguments, elevation, detection
condition, and whether MSI command lines set `ARPSYSTEMCOMPONENT=1`. Do not call
`Get-InstallShieldMsiInfo` to obtain the outer ProductCode: nested MSI metadata
is parcel evidence, while the suite ARP entry is authoritative.

`AdvancedUiInfo.InstallScriptEntryPoints` resolves literal
`CallInstallScript` arguments, and `$Info.InstallScriptInfo` contains effects
reachable only from those functions. `SilentSupport: NotApplicable` means the
suite owns silent invocation; it is not evidence that every suite event is
unattended. A reachable dialog requires VM validation of the containing event.

Evaluate target-specific package eligibility before selecting nested metadata,
then dispatch only locally extracted targets. `Unknown` is a possible package,
not evidence that it runs; `False` is statically excluded for the supplied
facts. The dispatcher does not download package `SourceUrl` values.

```powershell
$Eligibility = Get-InstallShieldAdvancedUiPackageEligibility `
  -Info $Info.AdvancedUiInfo -Architecture x64 -OSVersion 10.0 -BuildNumber 26100 -ProductType Workstation
$NestedPackages = Get-InstallShieldAdvancedUiNestedPackageInfo `
  -Info $Info.AdvancedUiInfo -Architecture x64 -OSVersion 10.0 -BuildNumber 26100 -ProductType Workstation
```

Also inspect `Selections`, `Modes`, `Actions`, `Events`, `AbortConditions`,
`Transactions`, and `WindowsFeatures` on `AdvancedUiInfo`. `Selections` is the
authoritative mapping from a feature to parcel IDs, while the ordered
`CatalogOrder` collection preserves package and transaction boundaries;
`SuitePackages` contains only executable package entries. Each `When`, `Detect`,
and abort predicate is returned as a structured condition tree. Registry,
installed-state, property, parcel-state, and extension predicates are not
evaluated against the analysis host; a listed or selected parcel is therefore
not automatically an unconditional dependency. `PackageArchitectures` and each
parcel's `Architecture` come only from explicit package platform metadata.
`Resolve-InstallShieldSuiteCondition` evaluates only caller-supplied platform
facts using `True`, `False`, and `Unknown`. Package-level `<Eligible>` and
install-selection conditions affect eligibility; `<Detect>` describes installed
state and operation planning and is deliberately excluded. Reuse the typed
`ExitBehavior`, `RebootRequest`, `RebootCodes`, `UpgradeType`, and
`TransactionMode` projections instead of reparsing raw property strings.

InstallShield setup prerequisites are separate `.prq` definitions. When they
are extracted, reuse `$Info.PrerequisiteDefinitions`; release-selected
references from `Setup.ini [ISSetupPrerequisites]` and MSI-authored feature
references are available through `$Info.PrerequisiteReferences`, and
`$Info.PrerequisiteEvidence` joins definitions only by exact identifier,
description, filename, or filename stem. To inspect a reviewed
definition directly, call it once and retain the result:

```powershell
$Prerequisite = Get-InstallShieldPrerequisiteInfo -Path .\Dependency.prq
$Prerequisite.Files
$Prerequisite.DetectionConditions
$Prerequisite.OperatingSystemConditions
$Prerequisite.SilentCommandLine
$Prerequisite.ReturnCodesToReboot
$Prerequisite.RequiresAdministrativePrivileges
```

The `.prq` payload URL, checksum, condition, and command line describe the
prerequisite package. They do not prove that the current release includes or
selects it unless `Setup.ini`, the MSI, or the suite catalog references the same
prerequisite. In the `.prq` Behavior record, `Lua="1"` means limited-user
compatible and the absence of `Lua` means the prerequisite editor's default
"requires administrative privileges" option remains enabled.

Inspect `$Info.RequestedExecutionLevel`, `$Info.ElevationRequirement`, and
`$Info.ElevationRequirementEvidence`. Use `ElevationRequirement:
elevationRequired` when the outer PE explicitly requests
`requireAdministrator`, or when an exactly matched, release-selected
prerequisite has `RequiresAdministrativePrivileges: true`. This prevents a
silent setup from reaching an interactive child UAC boundary or exiting when a
missing machine prerequisite cannot be installed. A selected prerequisite
without `SilentCommandLine` still requires manual review: elevation alone does
not make it unattended.

Do not infer required elevation from machine scope or from an unset MSI Word
Count bit 3. The latter means elevation *may* be required, not that an already
elevated parent is mandatory. `Vertexshare.WebpConverter` is a validated
negative case: its machine MSI has the bit clear but silent installation works
without elevation or preinstalled dependencies. Positive prerequisite examples
include `AFAS.ProfitCommunicationCenter.7`,
`AFAS.ProfitCommunicationCenter.8`, `NorconsultDigital.ISYLinker`,
`Thorlabs.ThorlabsDeviceSDK`, and `Thorlabs.TSP01`.

For PackageForTheWeb media, inspect `ContainerFormat` and
`PackageForTheWebCabinet`. `PackageForTheWebInfo` additionally records the
extracted `Setup.ini` product identity, configured command line/package name,
media-relative file list, exact root `NestedSetupPath`, selected
`NestedPayloadPath`, and ordered `LaunchChain`. `ConfiguredCommandLine` belongs
to the nested InstallShield launcher stage; do not treat it as an outer SFX
switch. The cabinet object records the validated absolute
CAB range, version, folder count, and file count. Extraction is still bounded by `-Name`,
safe-path checks, collision policy, catalog counts, and total expanded bytes;
neither the outer nor nested setup program is executed.

For InstallScript-only media, reuse `$Info.InstallScriptInfo`; do not parse `setup.inx` again. `SilentSupport` is `Supported`, `ResponseFileRequired`, or `Indeterminate`, and `ResponseFileRequirement` distinguishes `Embedded`, `External`, `None`, and `Unknown`. Only `Supported` is sufficient static evidence for the reported `SilentSwitches`. A reachable-path result that cannot be proven remains `Indeterminate` and requires VM validation.

`DialogTraces` contains the fresh-install and maintenance entry-point sequences.
`Source: DirectBytecode` identifies ordinary named event handlers;
`Source: FrameworkCallback` identifies the source-backed
`_ShowWizardPages -> IfxOnShowWizardPages` route. A framework callback with
reachable response-backed dialogs and no valid embedded `setup.iss` is reported
as `ResponseFileRequired`, not `Indeterminate`. `EmbeddedResponseValidation`
compares a shipped `setup.iss` with the reconstructed fresh-install order. A
syntactically valid but mismatched response file does not prove self-contained
silent support.

The same object contains the ARP and side-effect projection. Reuse `ProductCode`, `DisplayName`, `DisplayVersion`, `Publisher`, `Scope`, `DefaultInstallLocation`, `UninstallString`, `QuietUninstallString`, `DisplayIcon`, `URLInfoAbout`, `HelpLink`, `WritesAppsAndFeaturesEntry`, `AppsAndFeaturesEntries`, `RegistryWrites`, `RegistryItems`, `MediaRegistrySets`, `MediaRegistryWrites`, `ConditionalMediaRegistryWrites`, `CabinetFileGroups`, `CabinetComponents`, `MediaSetupTypes`, `MediaShellFolders`, `MediaShortcuts`, `ConditionalMediaShortcuts`, `Protocols`, `FileExtensions`, `ExecutedPayloads`, `FileOperations`, `DllOperations`, `PropertyHandlers`, `Shortcuts`, `OpcodeCoverage`, `UnsupportedOpcodes`, and `ArpValueSources`; do not parse the INX or cabinet header again with separate readers. Treat `DllOperations` as an opaque-code warning boundary, not as proof of the DLL's registry, file, or process effects. `PropertyHandlers` is structural compiler evidence and not a source of resolved runtime values. The `Features` and `SetupTypes` arrays on conditional media effects explain which authored selections can create them; they do not prove the runtime selection. The parser accepts `Setup.ini [Startup] ProductGUID` only when it is a valid GUID and requires compiled `MaintenanceStart`/uninstall-path evidence before promoting it to ARP `ProductCode`. A default media set can define additional visible uninstall keys; all distinct entries are returned while the MaintenanceStart GUID remains primary. If registration evidence is missing, `ProjectProductCode`, `ProjectName`, and `ProjectPublisher` remain diagnostic project metadata while manifest-facing ARP fields stay null. Registry-only values remain analysis evidence and are not inserted into WinGet `AppsAndFeaturesEntries`, whose schema accepts a smaller field set. The parser deliberately does not use `setup.iss [Application] Version`: response-file application metadata can be stale and is not the value written by `MaintenanceStart`.

Do not pass `-Name` during normal analysis. Use it only as a reviewed manual constraint when `MsiPayloadSelection.SelectionMethod` is unresolved and static inspection proves which payload the bootstrapper launches. If multiple MSIs are extracted and `Setup.ini` does not select one, the parser stops rather than using MSI architecture or enumeration order as a selector. An unselected MSI may be a prerequisite or chained package.

For direct MSI databases, `Get-MsiInstallerInfo` can also classify InstallShield
authoring markers. `InstallShieldScriptActions` includes runtime actions and
compiled custom actions with their sequence table, ordering, raw condition,
opaque target, and resolved `Function`. When `Binary.ISSetup.dll` is present,
`InstallShieldScriptInfo` exposes mapped `EntryPoints`, relative extracted
support files, bounded analysis, and warnings without returning temporary paths.
The parser opens the MSI once, streams the Binary-table payload through a 128
MiB bound, expands its validated `ISSetupStream`, and emulates only mapped
functions. Reuse this result rather than extracting `ISSetup.dll` or parsing
`Setup.inx` again.

`InstallShieldLauncherRequirement` reports whether
`ISVerifyScriptingRuntime` proves that an InstallScript MSI must be launched
through InstallShield `Setup.exe`; this verifier is launcher-contract evidence,
not proof that the MSI contains an extractable INX program. Conditions are not
evaluated outside Windows Installer. InstallShield-authored MSIs commonly use
`INSTALLDIR="<INSTALLPATH>"`, but confirm with
`$Info.InstallerBuilder -eq 'InstallShield'` because WiX and other builders can
use the same public property.

InstallScript MSI classification does not prove support for Windows Installer's
basic-UI `/passive` mode. `CrisisGo.CrisisGo` is a validated counterexample: a
standard-user `/passive` invocation requests elevation and then opens an
interactive InstallShield window. Its manifest therefore advertises only
`interactive` and `silent`, with quiet mode used for the silent path. Test each
InstallScript MSI in the VM before retaining `silentWithProgress`.

### Step 2: Identify The Visible ARP Owner

For Basic MSI or InstallScript MSI, use the extracted MSI values for installer-level `ProductCode` and `AppsAndFeaturesEntries.UpgradeCode`. Set `AppsAndFeaturesEntries.InstallerType` to `msi` or `wix` only when the visible ARP entry comes from that MSI/WiX payload.

If the MSI hides its native ARP entry and writes a custom one, use `$Info.AppsAndFeaturesInstallerType` and `$Info.AppsAndFeaturesProductCode` from MSI parsing. Validate in a VM when the wrapper controls visibility.

For InstallScript-only media, use `$Info.InstallScriptInfo.AppsAndFeaturesEntries` as ARP evidence. Explicit uninstall registry writes and complete `RegDBSetItem` values are stronger than `Setup.ini` defaults. Preserve existing `DisplayVersion`, `Scope`, and `DefaultInstallLocation` when the returned fields remain null. Custom assignments to `IFX_*`, `UNINSTALL_*`, `ALLUSERS`, `TARGETDIR`, or `ADDREMOVE_SYSTEMCOMPONENT` can still change or hide the entry, so never turn unresolved values into stronger claims than the parser returns.

For Advanced UI, use `$Info.AdvancedUiInfo.ProductCode` (the `SuiteId`) for the
outer EXE entry. Nested MSI `ProductCode`/`UpgradeCode` values are relevant only
when the nested MSI owns a visible ARP entry. When a parcel operation contains
`ARPSYSTEMCOMPONENT=1`, the nested MSI entry is intentionally hidden and the
suite's EXE ARP entry remains the visible owner.

### Step 3: Validate Silent Support And Nested Behavior

If no MSI can be extracted and the installer is InstallScript-only, inspect `$Info.InstallScriptInfo`. Accept `Supported` when the media embeds a valid default response file. Block `ResponseFileRequired`; validate `Indeterminate` in the VM. Do not infer support merely because `/s`, dialog names, or response-runtime strings occur in the compiled script.

For deep analysis or future response-file authoring, reuse the extracted `setup.inx` path and inspect the IR separately:

```powershell
$Program = Read-InstallShieldInstallScriptProgram -Path $Info.InstallScriptInfo.CompiledScriptPath
$Traces = @(Get-InstallShieldInstallScriptDialogTrace -Program $Program)
$FreshInstall = $Traces | Where-Object Scenario -EQ 'FreshInstall'

$Template = New-InstallShieldResponseFileTemplate `
  -Trace $FreshInstall `
  -ProductCode $Info.InstallScriptInfo.ProjectProductCode

$Template.Content
$Template.Warnings
```

The template generator fills only documented generic keys such as `Result`, `szDir`, `bOpt1`, `bOpt2`, and `BootOption`. Feature-tree/custom dialogs and unresolved branches are emitted as TODO evidence. Never remove those warnings or invent project-specific values. Validate a recorded or reviewed file structurally before VM use:

```powershell
Test-InstallShieldResponseFile -Path .\setup.iss -Trace $FreshInstall
```

These helpers assist analysis and authoring; they do not make response-file-dependent installers acceptable to winget-pkgs today.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) to distinguish Basic MSI, InstallScript MSI, InstallScript-only, and Advanced UI behavior, verify nested ARP ownership, and stop when silent installation requires a response file. Test prerequisite behavior from a checkpoint where the selected dependency is absent; compare unelevated and elevated silent runs, capture the outer and child exit codes, and verify whether the dependency was installed. For Advanced UI, compare the observed child process and arguments with `SuitePackages.Operations`, confirm whether the suite or a non-hidden parcel owns the visible ARP entry, and exercise events whose scoped `CallInstallScript` analysis reports reachable dialogs or unresolved calls. For MSI custom actions, compare the observed sequence with `InstallShieldScriptActions`; do not execute an opaque `fN` export directly.

## Implementation Sources

- [ISx](https://github.com/lifenjoiner/ISx)
- [Revenera SetupIni.exe and embedded Setup.ini](https://docs.revenera.com/installshield26helplib/helplibrary/SetupIniExe.htm)
- [Revenera Setup.ini reference](https://docs.revenera.com/installshield/helplibrary/SetupIni.htm)
- [Revenera Setup.ini Startup section](https://docs.revenera.com/installshield/helplibrary/StartupSection.htm)
- [Revenera Advanced UI and Suite/Advanced UI overview](https://docs.revenera.com/installshield26helplib/helplibrary/SteOverview.htm)
- [Revenera Advanced UI and Suite condition model](https://docs.revenera.com/installshield26helplib/helplibrary/SteBuildingConditions.htm)
- [Revenera package and transaction order](https://docs.revenera.com/installshield26helplib/helplibrary/SteInstallOrder.htm)
- [Revenera InstallShield Prerequisite Editor reference](https://docs.revenera.com/installshield26helplib/helplibrary/SetupPrereqEditor.htm)
- [Revenera prerequisite administrative-privilege setting](https://docs.revenera.com/installshield27helplib/helplibrary/SetupPrereqEditorAdminPrivs.htm)
- [Revenera required execution level](https://docs.revenera.com/installshield26helplib/helplibrary/SpecifyingRequiredExecution.htm)
- [Microsoft MSI Word Count summary property](https://learn.microsoft.com/en-us/windows/win32/msi/word-count-summary)
- [Revenera AddSuitePackage automation method](https://docs.revenera.com/installshield26helplib/helplibrary/AddSuitePackage-Ste.htm)
- [Revenera MaintenanceStart](https://docs.revenera.com/installshield/LangRef/LangrefMaintenanceStart.htm)
- [Revenera PRODUCT_GUID](https://docs.revenera.com/installshield/LangRef/LangrefPRODUCT_GUID.htm)
- [Revenera special registry functions and ARP values](https://docs.revenera.com/installshield/LangRef/RegSpecialFuncs.htm)
- [Revenera RegDBSetDefaultRoot](https://docs.revenera.com/installshield28helplib/LangRef/LangrefRegDBSetDefaultRoot.htm)
- [Revenera RegDBSetKeyValueEx](https://docs.revenera.com/installshield28helplib/LangRef/LangrefRegDBSetKeyValueEx.htm)
- [Revenera CreateRegistrySet](https://docs.revenera.com/installshield/LangRef/LangrefCreateRegistrySet.htm)
- [Revenera CreateShellObjects](https://docs.revenera.com/installshield/LangRef/LangrefCreateShellObjects.htm)
- [Revenera LaunchAppAndWait](https://docs.revenera.com/installshield/LangRef/LangrefLaunchAppAndWait.htm)
- [Revenera UNINSTALL_DISPLAYNAME](https://docs.revenera.com/installshield/LangRef/LangrefUNINSTALL_DISPLAYNAME.htm)
- [Revenera creating response files](https://docs.revenera.com/installshield30helplib/helplibrary/CreatetheResponseFile.htm)
- [Revenera response-file dialog sequence](https://docs.revenera.com/installshield27helplib/helplibrary/ResponseFileDialogBoxSequence.htm)
- [Revenera response-file dialog data](https://docs.revenera.com/installshield/helplibrary/ResponseFileDialogBoxData.htm)
- [darknesswind/IsDcc](https://github.com/darknesswind/IsDcc) (behavioral comparison only; source is not incorporated)
- [incognitte/isDcc](https://github.com/incognitte/isDcc) (legacy INS behavioral reference)
- [pawstas80/IsDccSharp](https://github.com/pawstas80/IsDccSharp) (modern INX behavioral comparison only)
- [Unshield](https://github.com/twogood/unshield) (MIT InstallShield cabinet format and Deflate behavior)
- [Microsoft SetupIterateCabinet](https://learn.microsoft.com/en-us/windows/win32/api/setupapi/nf-setupapi-setupiteratecabinetw)
- [Microsoft FILE_IN_CABINET_INFO](https://learn.microsoft.com/en-us/windows/win32/api/setupapi/ns-setupapi-file_in_cabinet_info_w)
