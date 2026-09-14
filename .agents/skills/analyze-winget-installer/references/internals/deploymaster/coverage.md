# DeployMaster coverage

## Supported capabilities

| Capability | Classic 2.5 | Header66 | Header70 | Header74 |
| --- | --- | --- | --- | --- |
| Structural detection | Yes | Yes | Yes | Yes |
| Runtime extraction | BZip2 | raw LZMA | raw LZMA | raw LZMA |
| Identity and destinations | Yes | Yes | Yes | Yes |
| Complete payload catalog and extraction | Yes | Yes | Yes | Yes |
| Components and destination trees | Yes | Yes | Yes | Yes |
| Registry writes | string and DWORD route | legacy delimited route | opcode route | opcode route |
| File associations | classic form-feed route | form-feed route | form-feed route | form-feed or current UTF-8 route |
| Prerequisites and completion | unresolved | Yes | Yes | Yes |
| Architecture-selected payloads | x86 observed | Yes | Yes | Yes |
| Built-in ARP | 2.5.3 live-proven | live-proven | live-proven | live-proven |
| Custom visible and hidden ARP | literal writes | literal writes | literal writes | controlled and live-proven |
| Silent installation | interactive-only | `/silent` | `/silent` | `/silent` |
| Portable settings | absent | absent | absent | Yes when compiled |
| Windows 10 ranges | absent | absent | Yes | Yes |
| Windows 11 ranges | absent | absent | absent | Yes |

"Yes" means implemented with a stable structural or controlled fixture. Conditional support-DLL, child-installer, launch-context, and runtime-generated effects remain separate evidence.

## Persistent and research fixtures

| Fixture family | Route | Purpose |
| --- | --- | --- |
| archived 2.5.3 media | `ClassicBZip2` | complete classic extraction, component forests, files, shortcuts, URL shortcuts, registry, associations, interactive-only runtime, and live ARP |
| archived 2.5.4 and 2.5.5 observations | `ClassicBZip2` | common runtime, identity, catalog, payload, and uninstaller structure; installed state not yet validated |
| archived 6.0.1 and 6.1.2 | `Header66` | 66-byte header, legacy registry route, form-feed associations, old relaunch and uninstall quoting |
| archived 6.5.1, 6.5.2, 6.5.3, and 7.1.1 | `Header70` | Windows 10 bounds, opcode registry, `/userall`, `/noadmin`, and fixed uninstall quoting |
| archived 7.2.0 and 7.6.0 | `Header74` | Windows 11 bounds, package settings, current catalog, and conditional path quoting |
| controlled 7.7 matrix | `Header74` | scope, marker 6, mixed architecture, file policies, associations, portable choices, URLs, custom ARP, prerequisites, expiration, and update policy |
| Brinno Video Player | locator-based production media | legacy production catalog and explicit x86 HKLM EXE ARP behavior |

The durable fixture cache is external to the repository. Generated, expanded, decompiled, and VM state belongs under ignored research storage and is not a committed parser dependency.

## Live installed-state evidence

Controlled VM validation covers locator releases 6.1.2, 6.5.2, 6.5.3, 7.1.1, and 7.2.0 plus current machine, user, elevated-user, dual-scope, mixed-architecture, portable-only, and custom ARP variants. It establishes registry hives and views, full locator ARP values, URL fallback, version splitting, uninstall quoting, generated uninstaller names, deployment-log tracking, and machine-scope silent no-op behavior.

Only classic 2.5.3 has live installed-state evidence. Its shared `%WINDOWS%\UnDeploy.exe` route, small ARP value set, display-name construction, 32-bit HKLM view, and DeployIT log value are not extrapolated beyond structurally common fields for 2.5.4 and 2.5.5.

## Known gaps

| Gap | Current handling | Evidence needed |
| --- | --- | --- |
| DeployMaster 3.x through 5.x | reject instead of extrapolating classic or locator grammars | durable installer or controlled builder media from those releases |
| Classic prerequisites and completion | retain bounded records and emit partial-effects diagnostic | paired 2.5.x projects or runtime decompilation plus installed-state comparison |
| Classic 2.5.4 and 2.5.5 installed state | project only structurally common evidence | checkpointed installation and uninstall comparison |
| Locator custom prerequisite fields and condition semantics | preserve descriptors and opaque fields | single-option builder differentials and runtime branch confirmation |
| Support DLL effects | report DLL, architecture, and manual-validation diagnostic | static analysis of the exact exports or VM validation |
| Optional locator `DisplayIcon` value | omit final path while retaining the ARP limitation | builder differential plus runtime resolution of the selected icon source |
| Expiration authoring mode | report compiled final date and message | not recoverable from known shipped media because source modes converge |
| `EstimatedSize`, `InstallDate`, source `Stub`, and indexed `DeployN.log` | identify as runtime-generated | concrete installed-state capture |
| Future layouts | reject | bounded fixture and a new data-driven route |

## Regression requirements

A framing change needs malformed synthetic coverage and at least one distinct archived generation. Scope, ProductCode, ARP values, silent behavior, generated command lines, and portable suppression require VM evidence when they depend on launch state. A new runtime token must be tied to reachable behavior before it becomes a public switch.
