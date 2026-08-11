# Chromium Setup manifest variants

[Back to the Chromium Setup workflow](workflow.md)

## Bare Chromium mini-installer

Upstream Chromium mini-installer defaults to user scope and accepts `--system-level` for machine scope. Silent installation does not necessarily require a separate silent switch; package-specific switches are forwarded to nested `setup.exe`.

```yaml
Installers:
- Architecture: x64
  InstallerType: exe # Chromium Setup
  Scope: user
  InstallerUrl: https://example.com/mini_installer.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - silent
  InstallerSwitches:
    Custom: --do-not-launch-chrome
    Log: --verbose-logging --log-file="<LOGPATH>"
- Architecture: x64
  InstallerType: exe # Chromium Setup
  Scope: machine
  InstallerUrl: https://example.com/mini_installer.exe
  InstallerSha256: <SHA256>
  InstallModes:
  - silent
  InstallerSwitches:
    Custom: --do-not-launch-chrome --system-level
    Log: --verbose-logging --log-file="<LOGPATH>"
```

The `Custom` values are Chrome examples, not universal Chromium defaults. Keep scope-specific `Custom` atoms on each installer entry; Dumplings can hoist only identical nested dictionary values. Add `ProductCode` only from accepted manifest history or installed-state evidence because the Chromium parser intentionally leaves it unresolved.

## Current Google Updater package

For the updater itself, current accepted `Google.GoogleUpdater` manifests use:

```yaml
Installers:
- Architecture: x86
  InstallerType: exe # Chromium Updater
  Scope: user
  InstallerSwitches:
    Silent: --install --silent
    SilentWithProgress: --install --silent
    Interactive: --install
    Log: --enable-logging
    Upgrade: --update
    Custom: --enterprise
- Architecture: x86
  InstallerType: exe # Chromium Updater
  Scope: machine
  InstallerSwitches:
    Silent: --install --silent
    SilentWithProgress: --install --silent
    Interactive: --install
    Log: --enable-logging
    Upgrade: --update
    Custom: --system --enterprise
```

Do not use this snippet for a tagged Chrome/other-application bootstrapper without verifying how the downloaded target installer receives its switches.

## Legacy Google Update/Omaha package

The first two `Google.GoogleUpdater` versions in winget-pkgs, `1.3.35.452` and `1.3.36.372`, are untagged Omaha runtime installers rather than Chromium Updater. Their scope-specific commands are:

```yaml
Installers:
- Architecture: x86
  InstallerType: exe # Omaha
  Scope: user
  InstallerSwitches:
    Silent: /silent
    SilentWithProgress: /silent
    Custom: /install "runtime=true" /enterprise
- Architecture: x86
  InstallerType: exe # Omaha
  Scope: machine
  InstallerSwitches:
    Silent: /silent
    SilentWithProgress: /silent
    Custom: /install "runtime=true&needsadmin=true" /enterprise
```

Both installers contain PE resource `B/102`, decode through LZMA + BCJ2 + TAR, and place `GoogleUpdate.exe` first in TAR execution order. Do not replace these Omaha slash switches with Chromium Updater `--system` switches.

## Tagged online or offline application bootstrapper

There is no safe universal snippet. A tag does not prove that the wrapper is online-only. For Omaha, first inspect `OfflineManifest.gup`: when present, it identifies the target version, package name, hash, size, action executable, arguments, and elevation requirement. When absent, read the tag, expand the embedded updater, capture its download, and validate the target application's final installer and ARP entry. Omaha/Updater command lines can describe updater installation while the tag selects a different application payload.
