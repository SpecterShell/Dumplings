# Astrum InstallWizard uninstaller and ARP

Astrum does not derive one universal ProductCode from package identity. Apps & Features evidence comes from compiled uninstall registry writes and must be interpreted with normal registry visibility, hive, view, condition, and variable rules.

## ARP projection

The parser converts compiled registry records to normalized writes, then selects entries below the Windows uninstall paths. A manifest-facing entry must be unconditional, visible, and have a resolved key leaf. Multiple visible candidates or both user and machine hives remain ambiguous.

`ProductCode` is the uninstall-key leaf. `DisplayName`, `DisplayVersion`, `Publisher`, `InstallLocation`, `UninstallString`, `QuietUninstallString`, and `DisplayIcon` come from values on that key. Missing optional fields stay absent. Unresolved values remain on raw `ArpEntries` but are omitted from `AppsAndFeaturesEntries` so WinGet cannot match on a template such as `<DynamicKey>`.

The built-in “hide from Add/Remove Programs” behavior can suppress the key entirely. Controlled Modern2 hidden-ARP media installs files and writes no uninstall key; it does not create a hidden `SystemComponent=1` substitute.

## Registry roots and views

HKLM establishes machine scope and HKCU establishes user scope. The x64-compliance option selects the 64-bit uninstall view; ordinary x86 Modern2 media writes WOW6432Node. Registry paths are reported in normalized logical form while `RegistryView` records the physical view.

Dynamic root or key variables prevent deterministic ProductCode projection. Literal Nowhere variables and the verified empty Registry/HKEY_CLASSES_ROOT fallback may resolve; general registry lookups may not use their compiled default without runtime evidence.

## Generated uninstaller

The generated uninstaller is stored as a standalone GZip member named by footer offset and size. Its installed filename is determined from the compiled uninstaller path or ARP command. Default extraction emits it only when uninstallation is enabled and the resolved destination is below the default installation directory. Raw extraction preserves otherwise unplaced uninstaller data under `_astrum`.

Disabling uninstallation does not necessarily disable custom ARP writes. Controlled media writes a complete visible row whose `UninstallString` points to `Odd Uninstaller.exe`, but the file is never created. The parser retains the truthful registry evidence and emits `Astrum.Uninstall.Disabled` because deleting the row would conceal a matching hazard.

## Installed-state matrix

| Fixture | Installed behavior | Parser consequence |
| --- | --- | --- |
| normal Modern2 | full 32-bit HKLM ARP, payload and uninstaller, exit `1` | ProductCode and success code are authoritative |
| asInvoker machine | unelevated refusal, exit `0`, no partial state | machine scope and caller elevation required |
| requireAdministrator | unelevated refusal, exit `5`, no partial state | `elevationRequired` |
| x64 compliance | 64-bit HKLM ARP and 64-bit Program Files | 64-bit registry view and resolved location |
| hidden ARP | files installed, no uninstall key | no ProductCode or AppsAndFeaturesEntries |
| no uninstaller | visible ARP but named uninstaller absent | retain ARP and emit risk diagnostic |
| license required | bare silent refuses; `/AcceptLicense` succeeds | add custom license switch |
| User Information | Modern2 silent installation succeeds | keep silent mode for Modern2 |
| BreakAlube | localized concatenated DisplayName and custom icon/path | preserve exact resolved ARP tuple |

Comparison must use the VM installed-state transition, not ambient hidden registry changes already present in the baseline. The package-owned visible key and its value kinds are the authoritative tuple.
