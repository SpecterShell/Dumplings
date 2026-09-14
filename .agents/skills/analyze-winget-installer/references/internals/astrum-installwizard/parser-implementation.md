# Astrum InstallWizard parser implementation

The public parser is `Get-AstrumInstallWizardInfo`; detection, metadata readers, extraction, analyzer routing, and WinGet projection reuse that structural model. A caller should parse once rather than invoke several `Read-*FromAstrumInstallWizard` functions over the same file.

## Detection pipeline

1. Resolve the filesystem path before managed access and open the candidate once with read sharing.
2. Validate PE structure and determine the logical end from the security directory when signed.
3. Test the catalogued trailer/footer routes without backward-scanning arbitrary magic bytes.
4. Validate the footer self pointer, protected configuration range, installation-item table, file count, descriptor width, payload ranges, and exact catalog endpoint.
5. If ordinary media fails, test the bounded 96-byte tiny descriptor and require its decompressed inner PE to pass the complete ordinary route.
6. Reconstruct spanned media only from explicitly ordered companions whose aggregate size exactly fills the logical gap.

Marker strings and PE product identity are weak analyzer hints. `Test-AstrumInstallWizard` returns true only after the complete structural route validates.

## One-pass ownership

`Open-AstrumInstallWizardContainer` owns any temporary tiny or spanned material and returns one context containing trailer, footer, decoded configuration, installation items, file records, and the logical stream. `Get-AstrumInstallWizardInfo` derives PE, ARP, association, architecture, dependency, switch, and diagnostic evidence from that context. `finally` closes owned temporary resources while preserving caller-independent behavior.

Selective PE analysis materializes only bounded EXE and DLL payloads. Full extraction streams directly from each record. PowerShell arrays are created at the public boundary; inner loops use typed lists and bounded streams to avoid large `Object[]` copies.

## Extraction policy

Omitting `-Name` selects every installed payload plus a resolvable enabled generated uninstaller. `-RawEntries` additionally exports decoded configuration, footer bytes, each descriptor, pre-catalog gaps, wrapper evidence, companion data, and an otherwise unplaced uninstaller under `_astrum`.

Paths are resolved through the shared safe-extraction helper. `<InstallDir>` entries become paths relative to the extraction root. Other known destinations are isolated below `_destinations`; unresolved expressions go below `_unresolved`. Traversal, rooted output, duplicate unsafe paths, record-count overflow, expanded-byte overflow, malformed GZip, size mismatch, and missing spanned bytes fail at the owning layer.

Interactive `CollisionAction` prompts only after a collision. Internal parser callers use `Rename` so analysis cannot block on a prompt.

## Diagnostics

Raw parser diagnostics are context-neutral. Notable IDs include `Astrum.Arp.Ambiguous`, `Astrum.Scope.Ambiguous`, `Astrum.Arp.Unresolved.*`, `Astrum.Payload.Conditional`, `Astrum.Execution.NestedPayload`, `Astrum.Operation.UnknownCode`, `Astrum.Variable.UnknownCode`, `Astrum.PostInteractive.SemanticsIncomplete`, `Astrum.Silent.UserInformationDialog`, `Astrum.Silent.UserInformationDialogIgnored`, `Astrum.Silent.LicenseAcceptance`, `Astrum.Silent.LegacyRuntimeVersionRequired`, `Astrum.Elevation.CallerRequired`, and `Astrum.Uninstall.Disabled`.

The WinGet layer assigns scenario severity. During manifest update, an incomplete field preserves existing metadata; a proven installer-family mismatch remains blocking. During full analysis, unknown operation semantics, nested execution, unresolved ARP, and disabled-uninstaller risks require review.

## Adding format support

Add a catalog route only after a bounded fixture proves a physical difference. Record footer offsets, descriptor widths, condition framing, profile selection, compression, success codes, validation invariants, and a stable fixture hash. Do not branch on application version or choose a profile because parsing “looks plausible.”

A newly assigned field needs a controlled one-option build or a source-backed runtime path, plus a malformed-input test around its range. Runtime effects that influence ARP, scope, elevation, switches, or installed files need VM comparison before projection changes.
