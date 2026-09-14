# Kachina parser implementation

## Detection

Strong detection requires a valid PE, a bounded Kachina TLV sequence after the PE image, exactly one configuration record, strict JSON, and non-empty `appName`, `publisher`, `regName`, and `exeName`. Indexed media must begin with `\0CONFIG` or `\0INDEX`, and each compact-index entry must match a sequential TLV boundary. Marker strings alone are rejected.

## Parse pipeline

1. Resolve and open the PE once.
2. Locate the final mapped PE boundary and candidate TLV sequence.
3. Parse the DOS pre-index when present.
4. Sequentially validate every TLV and decode control JSON.
5. Cross-check compact-index entries without dropping appended records.
6. Map metadata paths to payload hash records and patch records.
7. Selectively extract the main executable and adjacent PE files for architecture and dependency analysis.
8. Compose ARP, scope, switches, system effects, diagnostics, and unresolved fields.

## Extraction

`Expand-KachinaInstaller` expands every installed payload file when `-Name` is omitted. It can export raw control, patch, and prerequisite records with `-RawEntries`. Normal extraction also reconstructs updater and uninstaller executables. Internal analysis extracts only the main executable and relevant adjacent libraries to a temporary directory.

Payload files are streamed through bounded Zstandard decompression. Expected decompressed size and MD5 or XXH3-128 are verified before publication. Several metadata paths can reuse one record; each output path is validated independently. Path traversal, duplicate output, excessive entries, excessive bytes, recursion, and collision behavior use the shared extraction infrastructure.

## Diagnostics

Container/index inconsistencies are metadata diagnostics. Unknown UAC strategy affects only scope and elevation. Missing source entries affect only source evidence. Config-only media affects display version and payload fields. Payload catalog, decompression, architecture, and dependency analysis messages affect their own fields rather than inheriting every unresolved field in the result.

Raw parser diagnostics have no workflow level. Detection, full analysis, manifest authoring, manifest update, and extraction resolve them through the shared scenario policy.

## Performance

The installer is opened once per top-level operation. TLVs are indexed by name after one sequential scan. JSON control records are bounded and decoded once. Payload content is decompressed only for requested extraction or selective PE analysis. Runtime-package records and HDiff patches are catalogued without decompression or execution.

## Safety limits

The parser bounds configuration and metadata JSON, name length, record count, record length, index count, aggregate payload analysis, decompressed output, and generated executable length. Every offset and size is checked against the file before reading. Caller-owned paths are resolved before managed code access, and temporary analysis directories are removed in `finally`.

