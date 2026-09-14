# Astrum InstallWizard architecture

Astrum InstallWizard is a native setup compiler. The builder stores editable authoring state in an `.ai2` XML project, but generated media does not embed that project as its runtime model. The compiler writes a native setup engine followed by protected configuration records, installation-item groups, payload descriptors, payload streams, a generated-uninstaller stream, and a compact footer that joins those ranges.

## Layer model

```text
authoring layer
+-- .ai2 XML project
+-- source files and resource files
+-- dialog choices, requirements, variables, and operations
`-- output-media settings
          |
          v compiler
distributed setup
+-- native PE runtime
+-- compiled configuration and operation tables
+-- installation-item and file catalogs
+-- stored or GZip payload members
+-- generated-uninstaller member
`-- footer, optional trailer magic, and optional signature
          |
          v runtime
installed state
+-- selected files and resources
+-- shortcuts, registry, INI, and text changes
+-- optional nested program effects
+-- generated uninstaller
`-- optional visible Apps & Features registration
```

The parser operates only on the distributed setup. Builder project intent is useful when deriving a field through controlled comparisons, but the compiled bytes remain authoritative because the builder can clamp unsupported values or omit inactive records.

## Runtime responsibilities

The native runtime validates its compiled configuration, resolves variables, evaluates conditions, selects installation-item groups, expands payloads, applies file and system operations at configured phases, creates the generated uninstaller when enabled, and executes nested programs. These responsibilities are physically interleaved in the configuration, so parser output keeps each operation family separate instead of flattening it into one guessed installed-state list.

Runtime state is a trust boundary. Registry-, INI-, file-search-, dialog-, timer-, and DLL-backed variables cannot be evaluated from the analysis host. The parser returns their source records and keeps dependent values unresolved. Literal `Nowhere` variables and the source-backed empty Registry/HKEY_CLASSES_ROOT fallback are deterministic and may be expanded recursively under cycle and depth limits.

## Identity domains

Astrum has independent application, ARP, and uninstaller identities. `ApplicationName` and `ApplicationVersion` are package metadata. The uninstall-key leaf is the WinGet `ProductCode`. The ARP `DisplayName`, `DisplayVersion`, and `Publisher` come from explicit registry values when present. The generated-uninstaller path comes from the compiled uninstaller setting and can differ from all three.

An application name must never substitute for an unresolved or absent uninstall-key leaf. A configuration can suppress ARP entirely, write a custom key, create several conditional candidates, or write an ARP command while disabling generated uninstallation.

## Container variants

Normal media contains one complete logical Astrum setup. Tiny and tiny-verbose media wrap another complete Astrum PE in a bounded GZip member. Spanned 2.x media divides one logical byte address space between the setup EXE and explicitly ordered companion volumes. Authenticode signatures follow the logical Astrum ending and are not part of the payload catalog.

Every variant converges on the same parsed context: one validated format descriptor, one configuration profile, one installation-item table, one file catalog, and bounded payload ranges. Metadata is always taken from the inner logical setup rather than the wrapper.

## Security boundaries

The protected configuration is reversible obfuscation plus integrity bytes, not cryptographic secrecy. Decoding it is safe only because the parser reads primitive bounded records and never executes the setup, invokes an embedded DLL, or deserializes an arbitrary object graph. Nested executables and external DLL calls remain explicit manual-validation evidence.
