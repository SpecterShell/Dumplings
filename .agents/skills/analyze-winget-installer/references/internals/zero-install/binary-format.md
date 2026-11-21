# Zero Install binary format

## Managed PE layout

```text
managed PE
+-- DOS and PE/COFF headers
+-- CLR header
|   +-- metadata root BSJB
|   +-- #~ or #- tables stream
|   +-- #Strings and #Blob heaps
|   `-- ManifestResource table
+-- CLR type definitions
|   `-- source-backed Zero Install bootstrapper identity
`-- managed resources
    +-- EmbeddedConfig.txt or generation-specific INI
    +-- SplashScreen.png
    `-- content.* resources
```

The PE parser maps CLR resource offsets through the CLI header and ManifestResource table. Embedded resource records have a four-byte little-endian payload length followed by payload bytes. The returned data offset excludes that prefix and is bounded by the resource section.

## Configuration resources

Historical fixed-line resources are UTF-8 text whose line count and order identify one catalog profile. The builder reserves fixed widths and substitutes values in place. Trimming padding does not authorize a longer replacement or an unknown line layout.

INI generations use ordinary section/key text. `[bootstrap]` contains target URI, name, mode, arguments, integration, and content options. `[global]` contains runtime deployment options such as self-update URI and store configuration. An adjacent basename INI replaces the embedded INI on current runtimes.

## Embedded content names

```text
ZeroInstall.EmbeddedConfig.txt      -> EmbeddedConfig.txt
ZeroInstall.config.ini             -> config.ini
ZeroInstall.BootstrapConfig.ini     -> BootstrapConfig.ini
ZeroInstall.SplashScreen.png        -> SplashScreen.png
ZeroInstall.content.<relative-name> -> content/<relative-name>
```

Content names can encode feeds, images, integration stubs, implementation archives, and OpenPGP keys. Name recognition is source-backed and case-insensitive where the runtime is case-insensitive. Unknown entries remain raw content evidence.

## Feed XML

The root must be `<interface>` in `http://zero-install.sourceforge.net/2004/injector/interface`. Feed records use XML attributes, nested groups, inherited collections, and namespace-qualified capability records. DTD processing and external entity resolution are disabled.

`xml:base` is resolved from document root through the owning element and then against caller-supplied feed URI. Relative references remain unresolved without an absolute base.

## Implementation archives

Retrieval records can select an archive range through `start-offset`, extract a subtree, and place it below a destination prefix. ZIP uses `ZipArchive` plus bounded Unix metadata inspection. Other supported formats use the pinned managed archive reader. Archive symlinks and hardlinks are rejected because ordinary Windows extraction cannot preserve their manifest semantics safely.

## Manifest digest

Zero Install hashes a normalized file manifest, not compressed archive bytes. Records encode directories, files, executable files, content digests, Unix times, sizes, and names in deterministic order. `sha1new=`, `sha256=`, and `sha256new_` use the newer manifest ordering. Legacy `sha1=` uses SHA-1 file digests, interleaves files and directories by basename, emits directory modification times before their children, and omits a record for the root directory. Archive materialization restores directory timestamps after child writes before calculating this format.

