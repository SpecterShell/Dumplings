# QSetup architecture

## Builder and runtime

QSetup Composer compiles a project into `Setup.txt`, packs that instruction stream and payload files as independent zlib records, and appends the records to a native setup engine. The generated executable can also delegate work to the Execution Engine, external files, split companions, or nested installers.

```text
Composer project
+-- package identity and scope policy
+-- ordered file and destination groups
+-- shortcuts, associations, registry, INI, XML, and environment operations
+-- requirements and dialog policy
`-- Execution Engine actions and conditions
        |
        `-- compile
            +-- Setup.txt
            +-- numbered physical payload records
            +-- native setup engine
            `-- footer, split metadata, and optional signature
```

The setup engine interprets `Setup.txt`; the record stream only stores bytes. A physical name such as `00021#Composer.exe` is not the installed path until ordered `SET_SUB_DIR` and `SET_COPY_FILES` directives map it to a destination.

## Runtime layers

```text
outer setup process
+-- validate media and optional companion parts
+-- resolve scope, architecture state, and path aliases
+-- evaluate requirements and dialogs
+-- copy mapped payload records
+-- apply built-in and explicit system operations
+-- execute stage-specific commands
`-- create generated uninstaller and optional ARP entry

nested ownership
+-- outer QSetup ARP and uninstaller
+-- prerequisite or nested MSI/EXE ARP entries
`-- application first-run effects
```

`ExecutedPayloads` must be reviewed before assigning all installed-state ownership to the outer setup. A child MSI can own the visible application entry while QSetup retains a bootstrapper entry, or a setup action can delegate most work to another executable.

## Identity domains

`SET_COMPOSER_BUILD` identifies the producer build. `SET_PROG_NAME`, `SET_PROG`, and related directives identify the package. `SET_ADD_REMOVE_PROGRAMS_DISPLAY_NAME` controls the built-in uninstall-key name. Physical record names identify compressed entries. The generated uninstaller has an independent name controlled by an explicit option, compiled shortcut, or generation-specific formula.

These values should be compared, not substituted for one another. A nested MSI code in `SET_MSI_CODES`, a prerequisite GUID, PE version metadata, or the Composer build is not the outer ProductCode.

## Trust boundaries

The installer is untrusted input. Detection validates one preamble grammar, every adjacent record header, the exact terminal boundary, footer count and offsets, optional certificate framing, and a parsed `Setup.txt`. Marker strings do not establish the family.

Host-dependent conditions, external DLL calls, downloads, executable side effects, user choices, and application first-run behavior are runtime boundaries. The parser returns their command and condition evidence without executing them or borrowing state from the analysis host.
