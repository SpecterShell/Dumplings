# InstallAnywhere

## When To Use

Use `InstallerType: exe` for InstallAnywhere installers. InstallAnywhere is a generic EXE family, not a WinGet-specific installer type.

## Detection

Strong evidence includes `InstallAnywhere`, `Zero G`, `lax.nl.current.vm`, `com.zerog`, `IAClasses.zip`, `Execute.zip`, `InstallScript.iap_xml`, or `InstallerData/Disk1/InstData/Resource1.zip`.

## Binary Structure

The supported InstallAnywhere layout is a native launcher followed by a self-contained standard ZIP range. Installer logic may be nested in another ZIP entry.

```text
native PE launcher
`-- embedded ZIP range
    +-- local-file records
    +-- central directory
    +-- EOCD                         establishes archive start/end
    +-- InstallerData/Execute.zip   optional nested ZIP
    |   `-- InstallScript.iap_xml
    +-- IAClasses.zip
    `-- InstallerData/.../Resource1.zip and payloads
```

Dumplings derives the embedded ZIP base from the end-of-central-directory and central-directory offset; the first `PK` local header is not trusted as the archive base. Nested ZIP ranges receive independent entry, size, path, and expansion checks. `InstallScript.iap_xml` is structured Java-bean XML containing product identity and actions; built-in ARP synthesis may still require VM evidence.

## Manifest Shape

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

## WinGet Defaults And Overrides

WinGet supplies no InstallAnywhere defaults for generic `InstallerType: exe`. Treat unattended-mode, response, log, and location arguments as complete overrides for the detected generation. Explicitly list supported modes and do not assume a nested archive uses the same switches as the launcher.

## Step-By-Step Analysis

### Step 1: Parse And Extract InstallAnywhere Metadata

InstallAnywhere installers can contain a valid ZIP archive after the native stub. Locate the ZIP by validating the final ZIP end-of-central-directory record and deriving the archive start from the central-directory offset; do not assume the first `PK` local-file header is the archive start.

Use the PackageModule parser directly; it never launches the native stub or Java payload:

```powershell
$Info = Get-InstallAnywhereInfo -Path C:\Path\To\Installer.exe
Expand-InstallAnywhereInstaller -Path C:\Path\To\Installer.exe -Name 'InstallerData/Execute.zip'
```

`Get-InstallAnywhereInfo` returns validated archive-range evidence, embedded file names, product and upgrade IDs, display metadata, explicit uninstall-path registry writes when present, and a warning when built-in uninstall registration still needs VM validation.

The tested `FlowJo-Win64-10.10.0.exe` has a valid embedded ZIP range starting at offset `722436`. Its nested `InstallerData/Execute.zip` contains `InstallScript.iap_xml`, which is stronger evidence than raw string probing. Parse the `installerInfoData` object for product identity:

- `productName`: `FlowJo 10.10.0`
- `productID`: `0dd90bab-1f4a-11b2-a6b8-e5137808d66b`
- `productVersion`: `10.10.0.0`
- `upgradeCode`: `c1599e08-1f2b-11b2-a7ae-869c7b752225`
- `vendorName`: `FlowJo LLC`

This is better than arbitrary registry/version string probing, but it is still product identity evidence. In the tested sample, explicit `HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall` or `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall` writes were not present as literal registry actions in `InstallScript.iap_xml`; InstallAnywhere can synthesize its uninstall registration from built-in product metadata.

### Step 2: Resolve Uninstaller And ARP Metadata

Use parsed product metadata as candidate `ProductCode`, display name, version, publisher, and upgrade evidence. Require VM ARP delta validation when the exact visible uninstall key, `WindowsInstaller` flag, or scope matters.

### Step 3: Determine JVM, Payload Architecture, And Scope

Do not set `Scope` only because the installer is InstallAnywhere. Scope depends on the project configuration, elevation, and install root. Use VM evidence if static metadata does not explicitly prove HKLM or HKCU uninstall registration.

### Step 4: Validate Response And JVM-Dependent Behavior

Stop if the package requires an `installer.properties` response file that cannot be expressed statically in WinGet. Validate silent installation and ARP deltas in a VM for new packages.

## VM Validation

Follow [VM-Only Dynamic Validation Workflow](vm-validation-workflow.md) for JVM-dependent payload selection, install root, scope, and ARP deltas. Stop when unattended installation requires an unsupported response file.

### Known InstallAnywhere Packages

- `FlowJo.FlowJo` version < 11 (e.g., `10.10.0.0`).
