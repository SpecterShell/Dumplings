# Zero Install setup runtime

## Generic and application-bound launchers

A generic launcher deploys or starts Zero Install itself and has no target feed identity. An application-bound launcher passes `app_uri`, application arguments, and optional integration arguments to the deployed runtime.

```text
no app_uri
`-- generic runtime launcher or deployment bootstrapper

app_uri + run mode
+-- resolve target feed and implementation
`-- run target without desktop-integration ARP registration

app_uri + integration mode
+-- resolve target feed and implementation
+-- create requested desktop integrations
+-- write target ARP record on supported runtimes
`-- run target unless silent/no-run behavior suppresses launch
```

## Silent behavior

The old generic deployment bootstrapper used `--verysilent` for silent installation and `--silent` for progress UI. Those aliases disappeared in 2.14.5. Application-bound silent behavior was added later. From 2.23.0, GUI `--silent` keeps progress UI while console `--silent` is fully silent. From 2.24.0, GUI `--verysilent` suppresses progress.

The parser returns modes from both runtime version and bootstrapper type. A current generic `zero-install.exe` without application configuration remains interactive-only for target-package authoring even though the runtime exposes many ordinary command options.

## Machine scope and store path

Application desktop integration defaults to user scope. `--machine` selects machine integration from 2.23.1. If compiled integration arguments already contain `--machine`, the artifact is fixed to machine scope. Otherwise the same artifact can expose a machine variant.

`--store-path` is available from the INI generation and changes the implementation store. It is an install-location suggestion only when the artifact enables customizable store paths. Runtime `InstallBase`, command stubs, and generated icon paths still depend on deployed state.

## Integration categories

Integration removes selected categories before adding categories. `--add-all` includes capabilities, menu, desktop, send-to, aliases, auto-start, and default access points. `--add-standard` includes capabilities, menu, send-to, and aliases. Capability registration includes explicit-only capabilities; default access points exclude them. With no deterministic add/remove category, the runtime opens integration UI and static output cannot claim final associations.

## Solver and trust

The runtime validates feed signatures and trust, applies stability and rollout preferences, resolves dependencies and architecture, selects retrieval methods, materializes the implementation, and runs a command. The parser intentionally stops before these decisions. Caller-supplied feed XML is metadata evidence, not authorization to download or execute its references.

## Embedded and offline content

Content resources or a content directory can provide feeds, images, integration stubs, keys, and implementation archives. The runtime imports recognized files before normal network resolution. `Expand-ZeroInstallImplementation` models one explicitly selected retrieval method from caller-supplied local inputs and verifies the resulting manifest digest before publishing files.

## First run

The target application can create additional ARP values, protocols, extensions, user files, and services after launch. The built-in integration projection does not predict those effects. Capture after-install and after-first-run VM snapshots when target behavior matters.

