# Zero Install parser implementation

## Detection

Strong detection requires a valid managed PE and a source-backed Zero Install bootstrapper type. Current media must expose exactly one supported configuration resource. The historical generic route uses its CLR type identity and compatible runtime version without a configuration resource. Resource-name strings alone remain weak hints.

`Test-ZeroInstallInstaller` reads PE, CLR identity, and embedded configuration structure only. It ignores adjacent sidecars, feed text, and content directories so package layout cannot change family classification.

## Parse pipeline

1. Resolve and open the managed PE once.
2. Enumerate CLR types and ManifestResource entries through bounded PE metadata.
3. Select one format-catalog configuration profile.
4. Apply adjacent INI or historical appSettings precedence for full analysis.
5. Normalize app URI, mode, arguments, integration selection, and version-gated features.
6. Parse caller-supplied feed XML once when present.
7. project ARP, switches, scopes, capabilities, content entries, diagnostics, and unresolved fields.

## Feed safety

The XML reader prohibits DTDs and external resolution. It validates namespaces, safe identifiers, bounded numbers, URI bases, rollout rules, version ranges, and recipe step names. Unknown operations remain explicit and block complete recipe execution.

## Extraction APIs

`Expand-ZeroInstallInstaller` exports embedded configuration, splash, and content resources. Optional raw implementation-archive expansion is inspection only and emits an integrity diagnostic.

`Expand-ZeroInstallImplementation` requires one caller-selected implementation plus local retrieval artifacts and copy-from roots. It applies archive, file, rename, remove, and copy-from records in order inside a temporary staging tree. It computes and verifies the normalized manifest digest before copying selected files to the destination. For legacy `sha1=`, it records source directory timestamps during archive extraction and restores them after every recipe operation because writing children changes parent timestamps. `-SkipManifestDigestCheck` is explicit unsafe research behavior and must not be used as package identity evidence.

## Diagnostics

Profile/version disagreement affects detection and installability. Missing feed content affects target metadata fields. URI mismatch is metadata and security evidence. Interactive integration selection affects protocols and extensions. ARP feature boundaries affect ProductCode and Apps & Features fields. Raw content archives affect payload integrity. These diagnostics remain scenario-neutral until the caller resolves them.

## Performance and bounds

The PE is opened once, CLR metadata is enumerated once, and only selected resource ranges are read. Feed XML is parsed once. Content-directory enumeration is non-recursive and bounded. Archive extraction is streaming where the provider allows it. Implementation digest generation walks the staged tree once with bounded entries and bytes. No solver, network request, child process, or external extractor is invoked.

