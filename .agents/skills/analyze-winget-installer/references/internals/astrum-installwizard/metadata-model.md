# Astrum InstallWizard metadata model

The compiled configuration is an ordered operation model, not a flat property bag. Parser output preserves the record family, action code, timing, condition, variable sources, and raw evidence needed to distinguish guaranteed installed state from runtime-dependent behavior.

## Identity

Legacy identity framing stores application name, application version, company, install path, URLs, icon, and uninstaller values in one fixed string sequence. Modern2 prefixes that sequence with a bounded runtime word and duplicate internal application/company names, then separates install icon, language strings, default language, generated-uninstaller path, and command.

`DisplayName`, `DisplayVersion`, and `Publisher` prefer one visible unconditional resolved ARP row. They fall back to application identity only when the corresponding ARP value is absent. `ProductCode` never falls back: it is emitted only from a resolved uninstall-key leaf.

## Operation families

The catalog stores source-backed enum names for text, file, interactive, timing, and condition codes. Consumers should use `OperationName`, `ActionName`, `TimingName`, and `OperatorName` and retain numeric codes for forward compatibility.

Text actions add, append, insert, delete, or replace text. File actions copy, delete, move, rename, create directories, or remove directories. Interactive actions execute programs, open documents or sites, explore folders, show messages, terminate installation, ask questions, collect text, or assign variables. Action timing spans startup, each standard dialog boundary, post-installation, and shutdown.

Interactive action `0` executes a program and action `6` executes and waits. Both become `ExecutedPayloads`; the parser does not assume a child is silent, owns ARP, or receives the outer command line.

## Conditions

Conditions retain operating-system masks and bounded terms. Term operators cover equality, inequality, ordering, containment, and binary-and behavior. Static consumers may identify literal conditions but should not collapse a registry-, file-, dialog-, timer-, or DLL-backed term into a Boolean from the analysis machine.

Conditional files and registry writes remain candidate evidence. Extraction may return their physical content, but a manifest-facing ARP entry must be unconditional, visible, and fully resolved.

## Variables

Each custom variable stores name, type code, source code, default value, three source locations, and flags. Known types are Text and Number. Known sources are Registry, INI, Find file location, and Nowhere. Known flags mean Store drive only, Set true if exists, and User visible.

Literal `Nowhere` defaults resolve recursively. Registry source roots use signed values `0x80000000`, `0x80000001`, and `0x80000002` for HKEY_CLASSES_ROOT, HKEY_CURRENT_USER, and HKEY_LOCAL_MACHINE. BreakAlube proves one narrowly defined fallback: an empty Registry/HKEY_CLASSES_ROOT lookup uses its compiled default. Other registry records remain dynamic even when they also carry a default.

Built-in variables include application/company identity, install directory, Program Files, Common Files, Windows, system, temporary, Start Menu, Programs, Startup, and Desktop roots. Conversion to manifest-safe paths uses `%ProgramFiles%`, `%ProgramFiles(x86)%`, `%LOCALAPPDATA%`, `%APPDATA%`, `%WINDIR%`, and related stable tokens rather than expanding against the analysis host.

## Requirements and options

Modern2 sparse offsets expose CPU speed/vendor/features, memory, Windows platform and version selectors, DirectX, display resolution and bit depth, .NET Framework, Java, wave playback, MIDI, joystick, User Information flags, silent-by-default, no-uninstallation, x64 compliance, require-admin, direct license approval, and prohibit-silent policy.

The Java version is variable length. Fields after it are anchored to its terminator, while end-relative license bytes are anchored to the option block ending. This prevents a longer Java string from shifting silent, uninstall, x64, or elevation flags into unrelated bytes.

Legacy1 and Early2 option tails remain bounded evidence because applying Modern2 offsets would fabricate policy. `AssignedFields`, `AssignedByteCount`, and `UnassignedRanges` show what the parser used without warning merely because unrelated builder settings remain opaque.

## Resources and associations

Builder Resource files use ordinary file records rooted at `<ResourceDir>`. Compiled dialog and image bytes can also occupy otherwise unrouted pre-catalog ranges; these are exportable in raw mode but remain untyped.

Registry writes feed the shared association projector. Literal `Software\Classes` extensions, ProgIDs, commands, icons, and protocol markers become association evidence. Associations created by nested programs, conditional writes, unresolved variables, or first-run application logic remain outside static projection.
