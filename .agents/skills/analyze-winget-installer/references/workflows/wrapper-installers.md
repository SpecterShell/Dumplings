# Wrapper installers

Use this workflow for SFX archives, bootstrappers, nested MSI packages, and download-and-execute installers.

## Resolve the execution chain

1. Parse the outer configuration and identify the exact file or command it invokes.
2. Extract selected content through bounded static parser functions.
3. Analyze the nested payload as an independent installer.
4. Compose the outer forwarding syntax with the nested installer's silent, no-reboot, and install-location arguments.
5. Model the component that owns the visible ARP entry. `WindowsInstaller=1` makes an entry MSI to WinGet; `SystemComponent=1` hides it.
6. Add `AppsAndFeaturesEntries` only for meaningful differences from the installer and default-locale identity.

The outer architecture, filename extension, and family defaults do not prove nested behavior. A wrapper can contain MSI or EXE payloads, architecture-specific choices, prerequisites, or a download client.

Treat architecture words in filenames as routing hints. `win64` identifies x64, while bare `arm` may mean ARM32 or ARM64 and `win32` may describe x86 or x64 software. Resolve ambiguous labels from PE machine types, package metadata, installer conditions, and the installed primary binaries.

When official InstallShield or Advanced Installer downloads include both an EXE wrapper and a direct MSI, compare the direct MSI with the wrapper-selected MSI. Prefer only the MSI when both paths install the same release and visible ARP identity.

Do not infer the outer family from the application's framework or another release artifact. An Electron application can use NSIS, Inno, Squirrel, MSI, or a vendor bootstrapper, and an Inno or InstallShield wrapper can delegate ARP ownership to a nested MSI. Detect the physical outer file first, then compose its forwarding syntax with the selected nested installer's switches.

Use [VM validation](vm-validation.md) when static parsing cannot prove forwarding syntax, payload choice, ARP ownership, exit-code propagation, or download behavior.
