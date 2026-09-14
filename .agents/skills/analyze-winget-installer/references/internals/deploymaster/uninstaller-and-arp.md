# DeployMaster uninstaller and ARP

## Built-in identity

Locator-based normal installations use the compiled `DisplayName` as the uninstall-key leaf and therefore as parser `ProductCode`:

```text
HKCU or HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\<DisplayName>
```

The selected scope chooses HKCU or HKLM. Application architecture chooses the 32-bit or 64-bit registry view. Mixed media produces one conditional registration variant per supported scope and application architecture; filename equality is not sufficient to merge them.

Portable-only media does not execute this built-in route. User-choice portable media retains the normal registration variants because an ordinary installation remains possible.

## Locator value set

Runtime decompilation and controlled installations establish these built-in values: `DisplayName`, `UninstallString`, `NoModify=1`, `NoRepair=1`, `InstallLocation`, `DisplayVersion`, string `VersionMajor`, string `VersionMinor`, `Publisher`, `HelpLink`, `URLInfoUpdate`, `URLInfoAbout`, optional `DisplayIcon`, computed `EstimatedSize`, and runtime `InstallDate`.

`VersionMajor` and `VersionMinor` are the first two dot-separated display-version components without numeric normalization. `DEMO 6.1.2` therefore becomes `DEMO 6` and `1`. The application URL supplies `HelpLink` and `URLInfoUpdate`; when it is empty, locator runtimes fall back to the publisher URL. `URLInfoAbout` uses the publisher URL.

`EstimatedSize`, `InstallDate`, and the setup-source `Stub` value depend on runtime state and are named but not guessed. An authored application icon can produce `DisplayIcon`, but its final runtime value is not yet decoded and is omitted rather than fabricated.

## Uninstall command routes

The installed x86 uninstaller is `UnDeploy.exe`; x64 uses `UnDeploy64.exe`. Mixed media can store `UnDeploy32.exe` and rename it to `UnDeploy.exe` when selected.

Header66 and Header70 always leave the executable path unquoted and quote the log path:

```text
<InstallLocation>\UnDeploy.exe "<InstallLocation>\Deploy.log"
```

Header74 quotes each path only if that path contains a space. Standard Program Files and Local AppData destinations therefore produce:

```text
"<InstallLocation>\UnDeploy.exe" "<InstallLocation>\Deploy.log"
```

A space-free custom destination remains unquoted. This distinction comes from runtime control flow and live registry comparison, not preferred command-line style.

## Deployment tracking

The runtime writes the deployment-log path to a value named `<DisplayName>` under `Software\JGsoft\DeployIT` in the same hive and registry view as the built-in uninstall key. The adjacent `Stub` value records the setup source path at runtime. If the previous log remains, a reinstall can choose `Deploy2.log`, `Deploy3.log`, or another indexed name; static output reports the base path and identifies the runtime-generated name.

## Classic 2.5 registration

Controlled 2.5.3 installation establishes a 32-bit HKLM key whose leaf and ProductCode are the classic package `DisplayName`. The visible `DisplayName` concatenates publisher, package name, and version. The classic route writes only `DisplayName` and `UninstallString` to ARP; it does not write Publisher, DisplayVersion, InstallLocation, NoModify, NoRepair, EstimatedSize, or InstallDate.

```text
%WINDOWS%\UnDeploy.exe "<MachineInstallLocation>\Deploy.log"
```

The classic uninstaller is shared under `%WINDOWS%`, while the package log remains in the application folder. The same `Software\JGsoft\DeployIT` tracking convention records the log. Installed-state claims for 2.5.4 and 2.5.5 remain limited to the structurally common fields until those artifacts are validated live.

## Explicit Registry-tab ARP rows

DeployMaster does not expose a built-in hidden-ARP option. Explicit Registry-tab writes can create additional uninstall keys, override the built-in row when the key leaf matches, or create hidden records with `SystemComponent=1`. The parser groups literal unconditional values, excludes hidden rows from `AppsAndFeaturesEntries`, and preserves every raw write.

Controlled projects establish a visible HKLM custom row, a hidden HKLM row, and a user project that writes a visible HKCU custom row plus a hidden HKLM row while elevated. The builder enforces corresponding hive constraints. A custom ProductCode is a second package identity unless its uninstall-key leaf matches the built-in display-name key.

## Validation consequences

Compare `BuiltInRegistrationVariants` with the actual launch scope and architecture. Confirm `UninstallString`, registry view, log path, custom rows, hidden-row visibility, and stale-key behavior after silent uninstall. Do not add optional ARP values that static structures cannot establish.
