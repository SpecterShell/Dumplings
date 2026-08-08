# Installer defaults, switches, and return codes

### InstallerSwitches

WinGet fills each missing known switch key independently. Omit a manifest switch key when its complete value is identical to the WinGet default:

| Effective installer type | `Silent` | `SilentWithProgress` | `Log` | `InstallLocation` |
| --- | --- | --- | --- | --- |
| `msi`, `wix`, `burn` | `/quiet /norestart` | `/passive /norestart` | `/log "<LOGPATH>"` | `TARGETDIR="<INSTALLPATH>"` |
| `nullsoft` | `/S` | `/S` | none | `/D=<INSTALLPATH>` |
| `inno` | `/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART` | `/SP- /SILENT /SUPPRESSMSGBOXES /NORESTART` | `/LOG="<LOGPATH>"` | `/DIR="<INSTALLPATH>"` |
| All other effective types | none | none | none | none |

- If one key differs, include the complete replacement for that key; WinGet does not merge individual command-line tokens into an overridden value.
- Every manifest-authored `InstallLocation` value, or install-location argument embedded in `Silent` or `SilentWithProgress`, must protect `<INSTALLPATH>` with installer-supported quoting. Prefer quoting the path value. Use whole-switch quoting only when static documentation or VM validation proves that path-only quoting fails, and represent the literal double quotes with a single-quoted YAML scalar. Do not copy the unquoted WinGet-generated NSIS default `/D=<INSTALLPATH>` into a manifest merely to make it explicit.
- Keep switches that prevent an automatic reboot in `Silent` and `SilentWithProgress`. Examples include MSI `/norestart`, Advanced Installer EXE `/norestart`, and InstallShield `/V/norestart`.
- Put behavior common to every install mode in `Custom`. In particular, post-install launch suppression belongs in `Custom`, not duplicated in the silent fields.
- Chromium mini-installer uses `Custom: --do-not-launch-chrome` when that switch is verified for the package.
- VS Code-derived Inno installers commonly use `Custom: /mergetasks=!runcode` to disable the run-after-install task. Verify the current installer before retaining it.
- Because `Custom` is appended after the selected interactive/silent switch, it applies consistently to all modes.
- Source: winget-cli [`GetDefaultKnownSwitches`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestCommon.cpp) and [`ShellExecuteInstallerHandler`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCLICore/Workflows/ShellExecuteInstallerHandler.cpp).

### InstallModes

- Apply this rule across all installer families, not only MSI/WiX.
- Omit `InstallModes` for WinGet-known installer types when WinGet's defaults accurately represent the specific installer.
- WinGet supplies default silent and silent-with-progress switches for `burn`, `wix`, `msi`, `nullsoft`, and `inno`. Inno has distinct `/VERYSILENT` and `/SILENT` defaults, so do not treat it as lacking `silentWithProgress` globally.
- Add `InstallModes` for a known type only when evidence proves that this specific installer supports a different subset from its WinGet type defaults.
- Specify it for generic `exe` and other unknown types. Most use `interactive` and `silent` because they do not distinguish silent-with-progress behavior.
- Include `silentWithProgress` for a generic type only when verified. Common examples include InstallShield EXE and Advanced Installer EXE wrappers over MSI that accept separate quiet and passive switches.
- Treat the array as an exact supported set, not a list of modes that merely appear plausible from family defaults.
- Source: winget-cli [`GetDefaultKnownSwitches`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestCommon.cpp).

WinGet-known behavior:

| Effective installer type | Behavior when `InstallModes` and switches are omitted |
| --- | --- |
| `msi`, `wix`, `burn` | WinGet supplies quiet and passive MSI switches for silent and silent-with-progress operation. |
| `nullsoft` | WinGet supplies `/S` for both silent modes. |
| `inno` | WinGet supplies `/VERYSILENT` for silent and `/SILENT` for silent-with-progress, with its standard suppression/no-restart arguments. |
| `msix`, `appx` | Deployment uses the packaged-app path rather than EXE command-line switches; omit `InstallModes` unless schema/package evidence requires a restriction. |
| `portable` | No installer wizard mode applies; omit `InstallModes`. |
| `zip` | Follow the effective `NestedInstallerType`; do not infer modes from the ZIP container itself. |

### InstallerSuccessCodes And ExpectedReturnCodes

- `InstallerSuccessCodes` contains non-default process exit codes that mean installation succeeded. Do not add observed failure, cancellation, or reboot codes as success codes.
- During VM validation, record the process exit code for every interactive, silent, and silent-with-progress run that is tested, including runs that reboot, fail, or are cancelled.
- Omit `ExpectedReturnCodes` from snippets for known installer types. WinGet injects its own defaults for `burn`, `wix`, `msi`, `inno`, and `msix`.
- Add an explicit expected return code to a known type only for a package-specific addition or override not represented by WinGet's defaults.
- For a generic EXE, cancel the wizard before installation starts and record whether it returns a distinct cancellation code.
- For an EXE wrapper over MSI, determine whether it propagates MSI exit codes. If it does, mirror the complete current MSI mapping from winget-cli's `GetDefaultKnownReturnCodes`, because the outer generic `exe` type will not receive MSI defaults automatically. Use the [Windows Installer error-code reference](https://learn.microsoft.com/en-us/windows/win32/msi/error-codes) to interpret evidence.
- Do not assume a wrapper forwards the nested process exit code; verify it dynamically in the VM.
- WinGet does not inject a default expected response for a code listed in `InstallerSuccessCodes`, allowing a proven package-specific success code to override a known-type default failure interpretation.
- Source: winget-cli [`GetDefaultKnownReturnCodes`](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestCommon.cpp).

Default return-code families:

| Effective installer type | WinGet-provided defaults |
| --- | --- |
| `msi`, `wix`, `burn` | Windows Installer results covering install-in-progress, disk-full, service failure, reboot, cancellation, already-installed, rejected/blocked, invalid input, and unsupported language/platform cases. |
| `inno` | Exit codes `2` and `5` as `cancelledByUser`; exit code `8` as `rebootRequiredForInstall`. |
| `msix`, `appx` | Packaged-app deployment HRESULTs covering missing dependency, disk full, cancellation, already installed, downgrade, policy blocks, package in use, and unsupported system cases. |
| Other effective types | No default expected-return mapping is injected; add only package-specific, evidenced mappings. |

### ElevationRequirement

- Treat this field as author-controlled. Installer parsers may return elevation evidence for review, but Dumplings package updating does not add, replace, or remove `ElevationRequirement` automatically. The same artifact can require different behavior for different scope entries, as in dual-scope packages such as `Anaconda.Miniconda`.
- Use `elevationProhibited` only when the installer cannot run elevated and explicitly rejects or fails elevated execution. `Spotify.Spotify` is a known example.
- Do not use `elevationProhibited` on the user-scope entry of an installer that selects user or machine scope from current privileges. This includes many install4j packages, `Git.Git`, `JetBrains.*`, and `Mozilla.*`. Otherwise an elevated WinGet process cannot prefer the machine-scope entry correctly.
- Use `elevationRequired` only when non-elevated execution is unsupported: the installer rejects it, exits immediately, or cannot proceed without elevation.
- Known elevation-required examples include `AFAS.ProfitCommunicationCenter.*`, `CatoNetworks.CatoClient`, `Corsair.iCUE.4`, `Cribl.CriblEdge`, `CrisisGo.CrisisGo`, `DisplayLink.GraphicsDriver`, `DisplayLink.GraphicsDriver.HotDesking`, `ESET.Nod32`, `ExacqTechnologies.exacqVisionClient`, `Microsoft.VCRedist.2005.*`, `NorconsultDigital.ISYLinker`, `PaloAltoNetworks.PrismaAccessBrowser`, `RealVNC.VNCServer`, `RealVNC.VNCViewer`, `Thorlabs.TSP01`, and `Thorlabs.ThorlabsDeviceSDK`.
- Use `elevatesSelf` only when the installer conditionally requests elevation itself and remains valid when initially launched without elevation.
