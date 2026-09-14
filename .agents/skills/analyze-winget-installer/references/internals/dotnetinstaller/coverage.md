# dotNetInstaller coverage

## Supported capabilities

| Capability | Current support |
| --- | --- |
| structural detection | packaged resource route and explicit external-configuration route |
| configuration generations | grouped historical and ordered current XML |
| reference graph | caller-supplied files, deterministic resolution, cycles, depth, and schema mismatch |
| component types | MSI, MSP, MSU, EXE, CMD, and open-file |
| mode fallback | full, basic, and silent source selection |
| cabinet layouts | global/component, named/extensionless, and mixed sets |
| extraction | named/all embedded files plus explicit companions |
| nested MSI metadata | identity, scope, builder, visibility, architecture, associations, and install location |
| architecture/locale selection | positive and fully negated filters |
| switches | exact compiled capability profiles |
| diagnostics | configuration, payload, ARP, installability, and completion-command evidence |

## Persistent fixtures

| Fixture | Route | Regression purpose |
| --- | --- | --- |
| historical 2007 launcher | `ConfigurationOnly`, `LegacyQuiet` | pre-schema quiet-only runtime and absent payload identity |
| historical 2008 launcher | `ConfigurationOnly` | second early runtime sample |
| official 2.3 packaged native sample | `PerComponentCabinetsNamed`, `RebootControl` | nested MSI, all three end-to-end modes, and silent completion command |
| official 2.3 packaged HTML sample | HTML launcher | shared resource and execution model |
| official 3.2.115 samples | current stable route | current configuration and cabinet behavior |
| Wibu-Systems CodeMeter Runtime 9.10 | `GlobalCabinetNamed` | large wrapper, repeated locale routes, one WiX MSI, and unproven nested unattended commands |

Synthetic tests cover historical aliases, reference cycles and missing files, duplicate basename ambiguity, command fallback, product checks, companion payload selection, extraction collisions, and architecture/LCID filters.

The official packaged 2.3 and 3.2 samples and CodeMeter Runtime return no unresolved metadata fields. Every XML attribute remains available in the raw `Attributes` map even when it does not warrant a typed projection; this avoids silently dropping uncommon UI, check, response-file, or execution settings.

## Known boundaries

| Boundary | Current handling | Evidence needed to extend it |
| --- | --- | --- |
| target filesystem, registry, WMI, OS, and product state | preserve checks and conditions | VM state or a narrowly source-backed pure evaluator |
| downloaded payloads | return URL and destination evidence | caller supplies the exact trusted file |
| nested EXE, script, and open-file effects | retain command and payload evidence | nested parser or VM validation |
| response-file transformations | retain authored attributes | source-backed transform semantics and fixtures |
| completion commands | report selected command and risk | nested parser or VM validation |
| exact pre-schema runtime release | report structural and capability profiles | independent structured runtime identity |
| child exit-code propagation | no nonstandard success-code claim | source and VM evidence for the exact route |

These are runtime evidence boundaries rather than missing generic XML parsing. Do not emulate arbitrary component executables inside the dotNetInstaller parser.
