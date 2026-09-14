# Setup Factory coverage

## Capability matrix

| Capability | MultiFile31 | Classic4 | Legacy5 | Legacy6 | Modern7 | Modern8Plus |
| --- | --- | --- | --- | --- | --- | --- |
| Structural detection | Yes | Yes | Yes | Yes | Yes | Yes |
| Bootstrap catalog | Yes | Yes | Yes | Yes | Yes | Yes |
| Installed payload catalog | Yes | Yes | Yes | Yes | Yes | Yes |
| Installed payload extraction | Yes | Yes | Yes | Yes | Yes | Yes |
| Raw bootstrap extraction | Yes | Yes | Yes | Yes | Yes | Yes |
| Product name | Yes | Partial | Yes | Yes | Yes | Yes |
| Product version and publisher | Not present in verified record | Unresolved unless another exact record proves them | Yes | Yes | Yes | Yes |
| ProductCode and ARP | Not applicable to verified Windows 3.1 route | Built-in or literal registry evidence | Built-in or literal registry evidence | Built-in or literal registry evidence | Built-in or literal registry evidence | Built-in or literal registry evidence |
| Silent capability | Interactive-only | Interactive-only | Interactive-only | /S supported | Compiled gate | Compiled gate |
| Registry and associations | No supported record in verified media | Typed records | Typed records | Action records | Literal Lua evidence | Literal Lua evidence |
| Prerequisites | No structured route verified | No structured route verified | No structured route verified | No structured route verified | Supported where represented | Supported where represented |
| Embedded runtime release evidence | Structured IRSETUP.EXE catalog identity; no trusted runtime version | Yes | Yes | Yes | Yes | Yes |

"Yes" means a bounded implementation has a stable fixture. It does not mean every project option has a decoded semantic name.

## Remaining gaps

Setup Factory 4 outer records, installed files, per-file overwrite and shortcut policy, true-file-version comparison, OS and package predicates, font and ActiveX registration, storage mode, global settings, built-in uninstall identity, registry writes, and source-backed INI records are supported. Its decoded global format has no later product version, publisher, or default installation-directory fields, so those values remain unresolved unless another exact structured record establishes them. Separate execution and text-file records are not yet projected as system effects, and version 4 INI action codes other than the observed Set Value route remain unnamed.

Setup Factory 5 and 6 product and built-in uninstall metadata are supported. Version 5 `CRegistryData`, `CExecuteData`, `CFileOpData`, `CINIData`, `CVarRegistry`, OS and language predicates, package selectors, and complete `CConditionData` framing are decoded. Version 6 has a complete source-backed action-ID catalog, exact operands for manifest-relevant execution, assignment, registry, shortcut, reboot, dialog, and external-code actions, condition states, and grouped effect evidence. Version 5 condition outcomes remain scenario-dependent, and observed tail policy members without runtime-backed semantics remain preserved rather than named. Setup Factory 6 comparisons, arithmetic, host state, loop execution, jumps, and catalog-only action operands remain unresolved. The version 6 startup-default value for `%SilentMode%` is not projected, and startup assignments can still override `/S`, so these effects require controlled builder evidence or VM validation when they affect ARP identity, associations, scope, or unattended behavior.

Setup Factory 3.1 multi-file media is supported for structural detection, product identity, installed-file catalogs, selected or complete installed-file extraction, raw ARQ extraction, packed and expanded CRC validation, missing-companion diagnostics, and interactive-only installability. Unknown policy bytes in its installed-file records remain preserved without assigned semantics. The verified metadata does not contain a separate application version, publisher, Windows scope, or Apps & Features identity.

Full modern Lua control flow, conditional Lua actions, arbitrary external DLL effects, service execution semantics, scheduled operations, and modern standard shortcut action tables are not yet interpreted. Setup Factory 6 exposes external executable paths and arguments, shortcut records, service action identities, reboot actions, and DLL call operands, but it does not execute those actions or infer their target-machine results. Modern per-file shortcut fields and literal registry calls are exposed as evidence, but a custom action can still supersede them. Use VM evidence when any of these affect manifest fields or installability.

The optional Modern8Plus Lua discriminator and reserved fields are based on stable observed layouts from 8.1.1008.0, 9.0.3.0, 9.0.4.0, 9.1.1.0, 9.2.0.0, 9.5.1.0, and 10.2.0.0 builder media. Future media that violates those invariants must be rejected and added as a new structural profile rather than forced through the current route.

## Representative fixtures

The focused tests cover Setup Factory 3.1, 4.0, 5.0, 6.0.1.2, 6.0.1.4, 7.0.1, 7.0.3, 7.0.6.1, 8.1.1008.0, 9.0.3, 9.0.4, 9.1.1, 9.2.0, 9.5.1, and 10.2.0 media plus current package installers. Historical builders are cached outside Git under `Dumplings-TestFixtures`; malformed and decoder-edge fixtures use Pester's temporary directory.
