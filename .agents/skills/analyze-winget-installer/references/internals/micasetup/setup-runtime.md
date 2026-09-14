# MicaSetup setup runtime

## Startup and host behavior

The generated host can configure a single-instance mutex, temporary-path relaunch, requested elevation, logging, DPI awareness, services, localization, theme, pages, and exception handlers. `HostBehavior` reports the resolved mutex and temporary-path fork state. These host settings do not independently prove package scope or unattended behavior.

MicaSetup v1 calls `UseElevated()` unconditionally. MicaSetup v2 accepts a nullable elevation request and also compiles a `RequestExecutionLevel` attribute. The parser uses a resolved `UseElevated` value first and the assembly attribute as supporting evidence. Conflicting or dynamic evidence leaves scope unresolved.

## Installation phases

```text
start setup
  -> enforce host policy and optional relaunch
  -> choose installation directory
  -> present license and customization UI
  -> close configured applications
  -> open and extract publish.7z
  -> apply optional directory ACL
  -> create shortcuts, autorun, PATH, firewall, and certificates
  -> create uninstaller and ARP state or Uninst.dat
  -> refresh Explorer when configured
  -> optionally launch the application
```

The WPF view model checks free space and target writability before extraction. Selected UI values can change shortcut and autorun behavior. Static configuration therefore establishes defaults and available operations, while VM evidence establishes the concrete route taken by one invocation.

## Installation paths

v1 chooses Program Files or Program Files (x86) from its x86 preference. v2 can prefer Program Files, Program Files (x86), `%LOCALAPPDATA%\Programs`, or `%APPDATA%`. Dumplings returns manifest-safe environment expressions and never expands a target path using the analyst's account.

Path preference is not payload architecture. `IsUseInstallPathPreferX86` changes the destination convention, while the configured main executable and native sidecars establish architecture.

## Payload and system operations

The runtime extracts `publish.7z` with an optional configured password. It can grant inherited `FullControl` to `Everyone` and `Users` on the installation directory when elevated and `IsAllowFullFolderSecurity` is enabled. Dumplings reports this as `MicaSetup.Security.PermissiveInstallAcl` because the permission change affects deployment security but does not map to a WinGet field.

Firewall, certificate, registry, and some cleanup operations are elevation-dependent. Overlay cleanup can use literal extensions and patterns or a custom callback. Literal rules are reported; callback effects are opaque.

## Command-line behavior

`CommandLineHelper` tokenizes arguments introduced by `-`, `--`, or `/` and accepts `=` or `:` values. Parsing a token is not proof that the runtime implements an installation mode. Upstream `/q` and `/a` work remains unfinished in the verified sources, so the parser returns `InstallModes: interactive` and no switches unless the exact fork has separately proven command handling.

Do not infer silent installation from `CommandLineHelper`, from an option key appearing in user strings, or from an application-specific argument. A fork needs source-backed handler evidence and unattended VM validation before its switches can enter a manifest.

## Dynamic boundary

Generated source can add service registrations, callbacks, network operations, downloads, custom pages, arbitrary file generation, and application launch logic. The parser does not execute those methods. Review source when available; otherwise compare before-install, after-install, and after-first-run evidence in a VM.
