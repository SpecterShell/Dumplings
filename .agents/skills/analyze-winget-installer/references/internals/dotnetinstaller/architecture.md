# dotNetInstaller architecture

## Producer and runtime

The managed InstallerLinker takes the native or HTML launcher, writes application version resources, embeds configuration XML, and stores payload cabinets as PE resources. The resulting file still executes the native dotNetInstaller runtime. Application `FileVersion` and `ProductVersion` therefore identify the packaged product and cannot identify the builder runtime by themselves.

The native runtime reads command-line state, loads the primary configuration, follows reference configurations, selects applicable install configurations, and runs each selected component. It owns orchestration, logging, reboot policy, and UI. Component installers own most installed files and usually own ARP registration.

## Evidence layers

| Layer | Static evidence | Runtime-dependent evidence |
| --- | --- | --- |
| PE runtime | launcher kind, requested execution level, compiled option tokens, exact schema token | current process elevation and relaunch outcome |
| Configuration graph | component types, filters, commands, downloads, references, controls, installed checks | selected optional components and machine-state conditions |
| Cabinet and sidecars | physical file paths, bytes, nested MSI databases | unavailable downloads and external files not supplied by the caller |
| Nested installer | ProductCode, UpgradeCode, MSI scope, builder, ARP visibility | custom actions and target-machine conditions |
| Completion phase | authored commands and mode fallback | arbitrary executable side effects and application launch behavior |

## Identity domains

Keep the outer application version, configuration schema, configuration and component IDs, nested ProductCode and UpgradeCode, and retrieval URLs separate. The outer PE version belongs to the packaged application. A nested ProductCode identifies one installed MSI product. Download URLs identify inputs and do not establish installed identity.

`RuntimeVersion` is authoritative only when `schema.version` agrees with an exact null-terminated token in non-resource PE data. This check avoids treating application version resources as runtime evidence.

## Configuration and component selection

The root can contain several install configurations and reference configurations. Locale, OS, processor architecture, and authored selection attributes narrow the graph. Required components can still have state-dependent installed checks. Optional controls can change selection interactively. Static analysis returns every route plus filter evidence; it does not choose a route from the analysis host's locale or architecture.

Reference configurations are separate documents loaded to a maximum depth of ten. The parser accepts only caller-supplied trusted copies, resolves the authored filename deterministically, detects cycles, and preserves document provenance.

## Payload namespaces

Global cabinet entries are visible to every component. A component cabinet is visible only to the normalized component ID that owns it. `#CABPATH` resolves within these embedded namespaces. `#TEMPPATH`, `#APPPATH`, and `#STARTPATH` refer to runtime files outside the cabinet namespace and require explicit companion evidence.

## Trust boundary

Configuration XML and cabinets are untrusted binary input. Parsing may decode XML, enumerate cabinets, inspect nested MSI databases, and calculate deterministic command routes. It must not download a component, invoke a nested executable, evaluate target registry or WMI state, or run completion commands on the host.

