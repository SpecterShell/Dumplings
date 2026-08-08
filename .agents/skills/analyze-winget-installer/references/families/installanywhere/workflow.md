# InstallAnywhere workflow

## When to use

Use `InstallerType: exe` for InstallAnywhere installers. InstallAnywhere is a generic EXE family, not a WinGet-specific installer type.

## Detection

Strong evidence includes `InstallAnywhere`, `Zero G`, `lax.nl.current.vm`, `com.zerog`, `IAClasses.zip`, `Execute.zip`, `InstallScript.iap_xml`, or `InstallerData/Disk1/InstData/Resource1.zip`.

## Static analysis

Read [InstallAnywhere Parser Internals](../../internals/installanywhere/overview.md) before changing detection, extraction, binary decoding, or parser limits.

### Parse and extract InstallAnywhere metadata

InstallAnywhere installers can contain a valid ZIP archive after the native stub. Locate the ZIP by validating the final ZIP end-of-central-directory record and deriving the archive start from the central-directory offset; do not assume the first `PK` local-file header is the archive start.

Use the PackageModule parser directly; it never launches the native stub or Java payload:

```powershell
$Info = Get-InstallAnywhereInfo -Path C:\Path\To\Installer.exe
Expand-InstallAnywhereInstaller -Path C:\Path\To\Installer.exe -Name 'InstallerData/Execute.zip' -CollisionAction Rename
```

`Get-InstallAnywhereInfo` returns validated archive-range evidence, embedded file names, ARP ProductCode, project UUID as `ProjectProductId`, upgrade code, display metadata, built-in uninstaller evidence, silent/console/response-file settings, instance-management state, and structured `SpeedRegistryData` writes and associations. It also returns `Actions`, `Rules`, `InstalledPayloads`, `ExecutedPayloads`, `Shortcuts`, and `Launchers` from the serialized Java-bean graph. `ConditionalActionCount` identifies records guarded by a rule expression, while `UnsupportedActionClasses` records action families that are cataloged but not semantically projected.

The tested `FlowJo-Win64-10.10.0.exe` has a valid embedded ZIP range starting at offset `722436`. Its nested `InstallerData/Execute.zip` contains `InstallScript.iap_xml`, which is stronger evidence than raw string probing. Parse the `installerInfoData` object for product identity:

- `productName`: `FlowJo 10.10.0`
- `productID`: `0dd90bab-1f4a-11b2-a6b8-e5137808d66b`
- `productVersion`: `10.10.0.0`
- `upgradeCode`: `c1599e08-1f2b-11b2-a7ae-869c7b752225`
- `vendorName`: `FlowJo LLC`

For this sample, `Get-InstallAnywhereInfo` reports `ProductCode: FlowJo 10.10.0`; `ProjectProductId` is the UUID above. The enabled `InstallUninstaller` action proves built-in ARP creation, while its runtime hive fallback leaves `Scope` unresolved. The structured `SpeedRegistryData` records also expose FlowJo's `.wsp`, `.jo`, `.jot`, and other file associations.

FlowJo's `ExecFile` action identifies `vcredist_x64.exe` and its nested arguments, while `MakeExecutable` records expose the LaunchAnywhere main class, JVM behavior, and LAX properties. These remain static action definitions: preserve each `RuleExpression` and correlate it with `Rules` before treating an action as a Windows execution path. Custom Java actions remain unresolved and require VM validation.

Evaluate platform-only conditions against an explicit target descriptor. The expression parser supports `!`, `&&`, `||`, and parentheses. It returns three-valued results; variable, registry, file, and custom-code rules remain `Unknown`, and the analysis host is never consulted.

```powershell
$WindowsActions = Get-InstallAnywhereActionEligibility -Info $Info -PlatformName 'Windows 11'
$WindowsActions | Where-Object State -NE 'False'

# Inspect one authored expression directly when routing a specific payload.
Resolve-InstallAnywhereRuleExpression `
  -Expression 'WINDOWS_RULE && !SERVER_ONLY' -Rule $Info.Rules -PlatformName 'Windows 11'
```

### Resolve uninstaller and ARP metadata

Use `ProductCode` only when the parser found an explicit uninstall key or an enabled built-in uninstaller without instance management. `ProjectProductId` is diagnostic project identity, not a substitute ARP key. When `InstanceManagementEnabled` is true, require VM evidence because the runtime can append `(N)` to the uninstall key. Require VM ARP delta validation when scope or conditional custom actions remain unresolved.

### Determine JVM, payload architecture, and scope

Do not set `Scope` only because the installer is InstallAnywhere. Scope depends on the project configuration, elevation, and install root. Use VM evidence if static metadata does not explicitly prove HKLM or HKCU uninstall registration.

### Validate response and JVM-dependent behavior

Stop if the package requires an `installer.properties` response file that cannot be expressed statically in WinGet. Validate silent installation and ARP deltas in a VM for new packages.

## Manifest shape

Switch documentation: [InstallAnywhere command line install and uninstall](https://docs.revenera.com/installanywhere/Content/helplibrary/ia_ref_command_line_install_uninstall.htm).

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # InstallAnywhere
  Scope: machine
  InstallerUrl: https://example.com/Product-1.2.3-x64.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - interactive
  - silent
  InstallerSwitches:
    Silent: -i silent
    SilentWithProgress: -i silent
    InstallLocation: -DUSER_INSTALL_DIR="<INSTALLPATH>"
  ProductCode: <ProductCode>
```

## WinGet defaults and overrides

WinGet supplies no InstallAnywhere defaults for generic `InstallerType: exe`. Treat unattended-mode, response, log, and location arguments as complete overrides for the detected generation. Explicitly list supported modes and do not assume a nested archive uses the same switches as the launcher.

## Apps & Features

Use structured parser evidence to identify the visible Apps & Features owner. Do not substitute metadata from a hidden or nested payload unless that payload writes the visible uninstall entry.

## Scope and architecture

Use explicit parser evidence for scope and installed payload architecture. Preserve existing manifest intent and use VM validation when either value is conditional or unresolved.

## VM validation

Follow [VM validation workflow](../../workflows/vm-validation.md) for JVM-dependent payload selection, install root, scope, and ARP deltas. Stop when unattended installation requires an unsupported response file.

## Known examples

- `FlowJo.FlowJo` version < 11 (e.g., `10.10.0.0`).
