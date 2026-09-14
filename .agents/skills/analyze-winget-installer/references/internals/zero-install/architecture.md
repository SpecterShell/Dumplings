# Zero Install architecture

## Components

Zero Install on Windows separates the application bootstrapper from the deployment runtime and signed feed model.

```text
application bootstrapper
+-- managed PE host
+-- embedded or adjacent bootstrap configuration
+-- optional splash and content resources
`-- launch/integration arguments
          |
          v
Zero Install runtime
+-- feed retrieval and signature/trust policy
+-- implementation solver
+-- store and cache
+-- recipe execution
+-- desktop integration
`-- application command execution
```

The bootstrapper can be generic or bound to one feed. It does not contain the complete target package model unless the caller supplies the feed XML. A feed can describe many implementations, architectures, dependencies, commands, entry points, capabilities, retrieval methods, and policy constraints. Parsing those records is not equivalent to solving them.

## Evidence layers

| Layer | Establishes | Does not establish |
| --- | --- | --- |
| CLR type identity | Zero Install bootstrapper family and historical generic route | target application identity |
| configuration resource or sidecar | feed URI, app name, mode, integration arguments, store options | feed metadata or selected implementation |
| caller-supplied feed XML | package metadata, implementations, dependencies, commands, capabilities, recipes | trust decision or final solver choice |
| embedded/content directory | local feed, icon, stub, key, or implementation archive inputs | acceptance, selection, or complete manifest integrity |
| installed runtime state | store base, trusted keys, cached implementations, preferences | facts recoverable safely from one installer file |

## Identity domains

The bootstrapper PE version identifies the Zero Install runtime release. The target package identity is the canonical absolute feed URI. Desktop integration transforms that URI with `FeedUri.PrettyEscape` to form the uninstall key. Implementation IDs and manifest digests identify one implementation tree and must not be used as ProductCode.

`DisplayVersion` remains empty for the built-in desktop-integration ARP row because Zero Install deliberately removes or omits that value. Feed implementation versions are solver candidates, not ARP DisplayVersion.

## Configuration precedence

Configuration storage changed independently from runtime behavior. The active configuration can come from a CLR resource, adjacent executable INI, or historical `EXE.config` appSettings. The parser applies source-backed precedence and retains the embedded configuration separately when a sidecar wins.

## Trust boundary

The parser can read bootstrap resources, decode caller-supplied feed XML without DTDs, enumerate recipes, and materialize one explicitly selected implementation from caller-supplied local artifacts. It does not retrieve feeds or artifacts, verify OpenPGP trust, select a stability policy, resolve distribution packages, run the solver, execute commands, or publish an unverified implementation tree.

