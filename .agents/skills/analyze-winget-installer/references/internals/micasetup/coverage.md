# MicaSetup coverage

## Supported capabilities

| Capability | Pack | OptionLegacy | OptionModern |
| --- | --- | --- | --- |
| Structural detection | Yes | Yes | Yes |
| Exact builder patch version | Usually unavailable | Usually unavailable | Usually unavailable |
| Generated scalar options | Yes for supported CIL | Yes for supported CIL | Yes for supported CIL |
| Literal arrays and official close objects | Limited by schema | Yes where emitted | Yes |
| Payload catalog and extraction | Yes | Yes | Yes |
| Constant encrypted payload | Yes when archive supports it | Yes | Yes |
| Dynamic payload password | Unresolved | Unresolved | Unresolved |
| Payload architecture and dependencies | Selective bounded analysis | Yes | Yes |
| Scope | machine from unconditional elevation | resolved host evidence | resolved host evidence |
| Built-in ARP | machine route | machine route | machine route |
| User-mode uninstall data | N/A in verified v1 | `Uninst.dat` | `Uninst.dat` |
| Hidden ARP | where configured | where configured | where configured |
| Built-in shortcuts and system effects | source-backed options | source-backed options | source-backed options |
| Literal static registry associations | where present | where present | where present |
| Arbitrary custom C# | reported, not executed | reported, not executed | reported, not executed |
| Proven silent installation | No | No | No |

"Yes" means a structural implementation and fixture cover that route. It does not imply that every custom method in the setup is statically understood.

## Persistent real fixtures

| Fixture | Route | Regression purpose |
| --- | --- | --- |
| Official v1.0.0 installer | `Pack` | Costura Pack references, `UsePack`, and unconditional elevated route |
| Official v1.1.0 installer | `OptionLegacy` | transitional `MicaSetup.Core.Option` plus `UsePack` and the historical autorun spelling |
| Official v1.3.0 installer | `OptionLegacy` | later v1 option schema and elevation behavior |
| Official v2.0.0 installer | `OptionLegacy` | v2 source reorganization on the same physical format |
| Official v2.5.4 installer | `OptionModern` | request-execution-level, WPF streams, path options, and payload sidecars |
| Official v2.5.6 installer | `OptionModern` | collection-expression arrays, overlay patterns, and multilingual resources |

Generated tests cover user and administrator scope, disabled and hidden ARP, registry views, custom paths, literal associations, official close-application object initializers, host-builder calls, malformed CIL, malformed `.resources`, encrypted archives, wrong passwords, collisions, and traversal.

## Known gaps

| Gap | Current handling | Evidence needed to close it |
| --- | --- | --- |
| Arbitrary custom C# | report unresolved compiled behavior | inspect available package source or validate effects in a VM |
| Dynamically computed option values | retain expression and source offset | add a bounded evaluator only for a pure, source-backed operation with fixtures |
| `RegistryKey` object flows | do not project partial writes | implement root, view, key lifetime, call, and condition state when a real package requires it |
| Custom overlay handler | report handler presence and literal rules | inspect handler source or compare post-install files |
| Unsupported close-application construction | preserve count or unresolved object evidence | isolate the constructor or method pattern with source and generated media |
| Silent installation | return interactive-only evidence | prove a fork-specific handler and validate unattended behavior |
| Exact builder patch version | report configuration compatibility | explicit structured runtime identity independent of replaced assembly identity |
| First-run application effects | outside setup projection | compare after-install and after-first-run snapshots |

These limits are trust-boundary choices. General managed-code execution would turn static analysis into running an untrusted installer.

## False-positive controls

The tests reject ordinary WPF applications, marker-only managed executables, standalone 7z archives, MicaSetup strings without a valid ResourceManager stream, and Kachina installers. Future detection changes must retain the configuration-host and exact payload-resource requirements.

## Validation expectations

A CIL evaluator change needs a generated method fixture and a distinct official artifact using the same lowering. A resource-reader change needs malformed-table tests and v1/v2 real media. ARP, scope, ACL, certificate, custom code, and first-run behavior require VM evidence when they affect manifest matching or deployment safety.
