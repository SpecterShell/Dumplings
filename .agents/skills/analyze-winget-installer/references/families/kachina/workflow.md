# Kachina workflow

## When to use

Use `InstallerType: exe` with `# Kachina` when static analysis confirms a Kachina TLV stream appended to a native PE. Kachina packages configuration, metadata, Zstandard-compressed application files, optional update patches, and optional prerequisite installers as separate records.

Do not route MicaSetup, an ordinary Tauri application, or an executable containing only the text `!KachinaInstaller!` here. Kachina and MicaSetup have unrelated containers and runtime behavior. BetterGI moved from MicaSetup to Kachina, but that history does not make the formats interchangeable.

## Detection

Run the analyzer, then use the strict detector when the result affects manifest authoring:

```powershell
$Analysis = Get-WinGetInstallerAnalysis -Path $InstallerPath
$IsKachina = Test-KachinaInstaller -Path $InstallerPath
```

`Test-KachinaInstaller` requires a valid PE, a bounded Kachina record sequence, one valid configuration object, and consistent indexed record boundaries when an index is present. Marker strings and Tauri metadata are not sufficient.

## Binary structure

```text
native PE installer
+-- DOS stub
|   `-- !KachinaInstaller! + five big-endian UInt32 fields
+-- PE sections and resources
`-- appended TLV stream
    +-- \0CONFIG or legacy .config.json
    +-- optional \0IMAGE or legacy .image
    +-- \0INDEX on indexed media
    +-- \0META or legacy .metadata.json
    +-- hash-named Zstandard payload records
    +-- fromHash_toHash HDiff patch records
    `-- optional raw prerequisite-installer records
```

Each TLV contains a four-byte magic, a big-endian UTF-8 name length, the name, a big-endian content length, and bounded content. Read [Kachina internals](../../internals/kachina/overview.md) when debugging a generation, index, payload, or extraction failure.

## Manifest shape

Kachina is a generic EXE family. The parser proves the following installer-level shape for the default Program Files route:

```yaml
Architecture: x64
InstallerType: exe # Kachina
Scope: machine
ElevationRequirement: elevatesSelf
InstallModes:
- interactive
- silent
- silentWithProgress
InstallerSwitches:
  Silent: -S
  SilentWithProgress: -I
  InstallLocation: -D "<INSTALLPATH>"
ProductCode: <regName>
```

Keep all three `InstallModes` values because WinGet does not supply Kachina defaults for generic EXE installers. A manifest formatter may move common fields to root level after all installer entries are complete.

## Static parsing

1. Parse the installer once and retain the result:

   ```powershell
   $Info = Get-KachinaInfo -Path $InstallerPath
   ```

2. Confirm `FormatGeneration`, `ProductCode`, `DisplayName`, `DisplayVersion`, `Publisher`, `Scope`, `DefaultInstallLocation`, `PayloadArchitectures`, `RuntimePackages`, `Diagnostics`, and `UnresolvedFields`. `ProductCode` comes from `regName`, which is the uninstall-key name used by Kachina.

3. Inspect `SupportedScopes` and `UacStrategy`. The default path is under `%ProgramFiles%` and is machine scope. `prefer-admin` and `prefer-user` can take a user route only when `-D` selects a writable user path and the process remains unelevated. Do not create a user installer entry until that exact path and switch route passes VM validation.

4. Inspect `PayloadFiles`, `PatchFiles`, `ConfiguredRuntimes`, and `EmbeddedRuntimePackages`. Configured runtime packages may be embedded or downloaded by Kachina. Treat them as prerequisite-delivery evidence, not automatic WinGet dependencies.

5. Expand only what the current decision needs:

   ```powershell
   Expand-KachinaInstaller -Path $InstallerPath -DestinationPath $Destination -Name '*.exe' -CollisionAction Rename
   ```

   Omit `-Name` to extract all installed application files plus the generated updater and uninstaller. `-RawEntries` exports physical TLV records, including patches and appended prerequisite installers, under `_kachina` without executing them.

6. Review `PayloadArchitectureInfo` and `DependencyInfo`. The outer Tauri stub architecture does not replace architecture evidence from the installed main executable and adjacent native DLLs.

7. Keep config-only media unresolved. `Get-KachinaInfo` can recover source and ARP behavior, but it does not fetch the online metadata or payload.

## Apps & Features

Kachina writes `SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\<regName>`. It uses HKLM when the installation process is elevated and HKCU otherwise. The built-in values include `DisplayName`, `DisplayVersion`, `Publisher`, `InstallLocation`, `DisplayIcon`, `UninstallString`, `EstimatedSize`, `NoModify`, `NoRepair`, and serialized installer metadata.

Use installer-level `ProductCode: <regName>`. Add `AppsAndFeaturesEntries` only when the visible ARP identity differs from the default locale identity or another nonredundant field is needed. The machine and user routes use the same key name in different hives.

## Scope and architecture

`force` supports only the elevated machine route. `prefer-admin` requests elevation outside recognized user locations. `prefer-user` requests elevation when the target is not writable. Kachina can therefore expose machine and user routes without a dedicated scope switch; the selected `-D` path and UAC outcome determine the hive.

Use `PayloadArchitectures` for the WinGet architecture. Do not use the outer stub alone, and do not use `neutral` when the package contains binaries.

## Validation notes

Follow [VM validation](../../workflows/vm-validation.md). Test `-S` and `-I` separately, record the exit code, confirm the application starts, and compare visible ARP entries after installation. For a proposed user route, use an explicit private `%LOCALAPPDATA%` or `%APPDATA%` destination and verify that no UAC prompt appears and the ARP key lands in HKCU. For machine scope, verify the HKLM entry and Program Files path.

If `RuntimePackages` is nonempty, validate on a checkpoint without those runtimes. Determine whether the exact artifact embeds the prerequisite or downloads it, whether failure is reported through the installer exit code, and whether WinGet needs a separate dependency entry.

## Known examples

- `babalae.BetterGI`: current indexed media. Release 0.63 configures .NET Desktop Runtime 8 and VC++ 2015+ x64; the tested artifact downloads them rather than appending their installers.
- AkashaNavigator 1.4.0: current indexed media with a small x64 payload, one HDiff patch record, and downloadable runtime configuration.

## Source references

- [YuehaiTeam/kachina-installer](https://github.com/YuehaiTeam/kachina-installer)
- [Runtime TLV reader](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/local.rs)
- [Pack writer](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/builder/pack.rs)
- [Runtime installation](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/installer/runtimes.rs)
- [ARP registry writer](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/installer/registry.rs)
- [Command-line arguments](https://github.com/YuehaiTeam/kachina-installer/blob/main/src-tauri/src/cli/arg.rs)

The upstream repository did not declare a license when this parser was implemented. Dumplings uses it as format and behavior evidence and contains an independently written Apache-2.0 parser.
