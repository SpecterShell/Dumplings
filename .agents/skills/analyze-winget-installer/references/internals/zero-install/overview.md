# Zero Install internals

This reference describes Zero Install Windows bootstrapper, feed, integration, and offline implementation structures consumed by Dumplings. Use the [Zero Install workflow](../../families/zero-install/workflow.md) for package analysis and WinGet authoring.

Read [binary notation](../../parser-development/binary-notation.md), [parser contracts](../../parser-development/contracts.md), and [performance guidance](../../parser-development/performance.md) before changing the parser.

## Mental model

An application bootstrapper is a managed PE containing a small deployment configuration. The target package model lives in a signed Zero Install feed. The deployed runtime applies trust and solver policy, retrieves one implementation, optionally creates desktop integrations, and runs a command. The parser can read each static layer but does not collapse them into a guessed selected package.

```text
managed bootstrapper
+-- source-backed CLR type identity
+-- embedded or adjacent configuration
+-- optional splash and content resources
`-- target feed URI and integration arguments
          |
          v
signed feed
+-- package metadata and entry points
+-- implementations and distribution packages
+-- dependencies, restrictions, bindings, and commands
+-- retrieval methods and recipes
`-- Windows capabilities
          |
          v
runtime-only policy
+-- signature trust
+-- architecture and stability selection
+-- rollout and dependency solving
+-- store placement
+-- desktop integration
`-- target execution
```

The canonical feed URI is package identity. Desktop integration transforms it into an ARP key. Implementation IDs and manifest digests identify implementation trees, not installed package ProductCodes.

## Reading path

1. [Architecture](architecture.md) explains the bootstrapper, runtime, feed, solver, identity domains, and trust boundary.
2. [Format history](format-history.md) records configuration profiles and source-backed feature boundaries.
3. [Binary format](binary-format.md) defines managed PE resources, configuration records, content names, feed XML, archives, and manifests.
4. [Metadata model](metadata-model.md) covers bootstrap options, feed inheritance, implementations, commands, dependencies, capabilities, and recipes.
5. [Setup runtime](setup-runtime.md) describes launch modes, silent behavior, scope, integration categories, solver policy, and first run.
6. [Uninstaller and ARP](uninstaller-and-arp.md) documents versioned registration behavior and ProductCode derivation.
7. [Parser implementation](parser-implementation.md) records detection, feed safety, extraction, diagnostics, limits, and performance.
8. [Coverage](coverage.md) lists fixtures and deliberate boundaries.

## Structural routes

| Route | Configuration source | Target identity |
| --- | --- | --- |
| historical generic bootstrapper | CLR type identity, no customizable resource | none |
| fixed-line application bootstrapper | generation-specific embedded text plus optional historical appSettings | embedded `app_uri` when configured |
| INI application bootstrapper | embedded INI replaced by adjacent basename INI when present | active INI `app_uri` |
| content-assisted bootstrapper | any configured route plus embedded or explicit content directory | same target identity; local retrieval inputs remain separate |

## Source references

- [0install/0install-win](https://github.com/0install/0install-win)
- [0install/0install-dotnet](https://github.com/0install/0install-dotnet)
- [Zero Install feed specification](https://docs.0install.net/specifications/feed/)
- [Zero Install on Windows](https://docs.0install.net/details/windows/)
- [nano-byte/common](https://github.com/nano-byte/common)
