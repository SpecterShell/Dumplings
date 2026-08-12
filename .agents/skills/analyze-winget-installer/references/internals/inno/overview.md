# Inno Setup internals

This directory explains how Inno Setup turns an `.iss` script and source files into an installer, how that installer starts, how setup records are evaluated, how installation and rollback work, and how the uninstaller reconstructs the reverse operations.

The emphasis is the Inno Setup producer and runtime. Dumplings-specific parser details are kept in [parser implementation notes](parser-implementation.md).

Use the [Inno Setup package workflow](../../families/inno/workflow.md) when the immediate goal is a WinGet manifest.

## Reading path

1. [Architecture](architecture.md) introduces the compiler, loader, setup engine, data streams, script VM, and uninstaller.
2. [Compiler and output assembly](compiler-and-output.md) follows source sections through record creation, compression, and final executable construction.
3. [Binary format](binary-format.md) describes the loader resource, embedded setup engine, setup-data streams, record framing, file locations, and payload chunks.
4. [Metadata model](metadata-model.md) documents the setup header and each record family written by the compiler.
5. [Setup runtime](setup-runtime.md) follows command-line processing, language selection, architecture mode, privilege respawn, wizard state, record filtering, installation, rollback, and exit codes.
6. [Constants, expressions, and Pascal Script](scripting-and-expressions.md) explains the three different dynamic-evaluation systems used by Inno Setup.
7. [Uninstaller and ARP](uninstaller-and-arp.md) covers AppId normalization, uninstall-key values, uninstall files, log records, upgrades, and uninstall execution.
8. [Format history and editions](format-history.md) explains ANSI/Unicode generations, structure identities, third-party editions, and major format transitions.
9. [Parser implementation notes](parser-implementation.md) maps these internals to Dumplings and lists the remaining static-analysis limits.

## One installer contains several programs and data sets

The familiar `Setup.exe` is usually a loader, not the full setup program mapped directly into the process.

```text
Compiled Setup.exe
+-- SetupLdr PE image
|   +-- icons, manifest, version resources
|   `-- RCDATA #11111 offset table
+-- setup-0 data
|   +-- setup-data signature
|   +-- encryption parameters
|   +-- compressed setup header and entry tables
|   `-- compressed file-location table
+-- compressed Setup.e32 or Setup.e64
|   `-- the actual Setup/Uninstall/RegSvr engine
`-- setup-1 payload data, when not disk-spanned
    `-- compressed file chunks
```

At runtime, `SetupLdr` validates its table, reads enough setup metadata to choose language and process early switches, extracts the setup engine to a protected temporary directory, verifies its CRC, and starts it with an internal `/SL5=` parameter. The setup engine reopens the original installer and reads `setup-0` and `setup-1` through the absolute offsets passed by the loader.

When `UseSetupLdr=no`, the output can instead be the setup engine itself plus adjacent `Setup-0.bin` and `Setup-1.bin` files. Disk spanning also moves payload data into `Setup-*.bin` slices and sets embedded `Offset1` to zero.

## Build-time and run-time models

The compiler converts source text into two broad forms:

- **Declarative records** for `[Setup]`, `[Languages]`, `[Types]`, `[Components]`, `[Tasks]`, `[Dirs]`, `[Files]`, `[Icons]`, `[INI]`, `[Registry]`, `[InstallDelete]`, `[UninstallDelete]`, `[Run]`, and `[UninstallRun]`.
- **Compiled Pascal Script bytecode** for `[Code]`, stored as an ANSI byte string in the setup header and later copied into the uninstall log.

Declarative records are not automatically unconditional. Most entry families carry version bounds, component/task/language selectors, a `Check` function name or expression, and optional `BeforeInstall` and `AfterInstall` callbacks. Setup evaluates those fields against the active installation state.

## The three identities often called a version

Keep these separate:

| Identity | Meaning |
| --- | --- |
| Inno Setup product version | Release of the compiler and runtime, such as 6.2.2 or 7.0.2. |
| `SetupID` | Fixed 64-byte compatibility signature at the start of setup-0, such as `Inno Setup Setup Data (7.0.0.3)`. It changes when serialized structures become incompatible. |
| PE file/product version | Version resource attached to SetupLdr or the prepared setup executable. Vendors can customize some version fields. |

A compiler release can retain an earlier `SetupID`. Several historical releases therefore use the same serialized layout. Format readers must select structures from `SetupID` and related layout evidence, not from PE `FileVersion` alone.

## Static and dynamic behavior

Inno Setup mixes several kinds of behavior:

```text
Compile-time
+-- preprocessor expansion
+-- script parsing and validation
+-- wildcard/source-file enumeration
`-- Pascal Script compilation

Initialization time
+-- command-line and INF loading
+-- setup-data decoding
+-- language and architecture selection
+-- constants and previous-install data
+-- privilege selection and possible elevated respawn
`-- InitializeSetup / InitializeWizard code events

Selection and install time
+-- type, component, and task selection
+-- version/language/component/task/Check filters
+-- BeforeInstall and AfterInstall callbacks
+-- file, registry, icon, INI, delete, and run actions
`-- uninstall-log recording and rollback

First application run
`-- outside Inno Setup; may add associations or other state
```

A learner should identify the phase that owns an observed value. A literal registry record is available statically. `{code:...}` is not. A registration performed by the installed application is not part of the installer format at all.

## Important source units

The official source is the primary specification.

| Area | Source |
| --- | --- |
| Shared serialized structures and IDs | `Projects/Src/Shared.Struct.pas` |
| Record serialization | `Projects/Src/Shared.SetupEntFunc.pas` |
| Compiler parser and output assembly | `Projects/Src/Compiler.SetupCompiler.pas` |
| Compression writer | `Projects/Src/Compiler.CompressionHandler.pas` |
| Outer loader | `Projects/SetupLdr.dpr` |
| Setup process entry | `Projects/Setup.dpr`, `Projects/Src/Setup.Start.pas` |
| Setup initialization and constants | `Projects/Src/Setup.MainFunc.pas` |
| Installation and ARP | `Projects/Src/Setup.Install.pas` |
| File extraction | `Projects/Src/Setup.FileExtractor.pas` |
| Script runtime bindings | `Projects/Src/Setup.ScriptRunner.pas`, `Setup.ScriptFunc.pas` |
| Uninstall log and replay | `Projects/Src/Setup.UninstallLog.pas`, `Setup.Uninstall.pas` |

## Source references

- [Official Inno Setup source](https://github.com/jrsoftware/issrc)
- [Official Inno Setup help](https://jrsoftware.org/ishelp/)
- [Official archived Inno Setup releases](https://files.jrsoftware.org/is/)
- [InnoUnpacker/innounp](https://github.com/jrathlev/InnoUnpacker-Windows-GUI)
