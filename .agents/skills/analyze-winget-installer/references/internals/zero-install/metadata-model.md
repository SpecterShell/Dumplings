# Zero Install metadata model

## Bootstrap configuration

The active configuration can supply `app_uri`, application name, launch mode, application arguments, desktop-integration arguments, catalog URI, self-update URI, key fingerprint, content directory, store-path customization, and estimated space. Generic launchers have no `app_uri` and therefore no target ProductCode.

Early `app_mode` can be `run`, `integrate`, or `none`. Later layouts infer integration from non-empty integration arguments. Application arguments and integration arguments remain separate.

## Feed root

The feed parser returns localized name, summary, description, publisher, homepage, replacement metadata, feed references, entry points, implementations, package implementations, requirements, restrictions, bindings, commands, retrieval methods, and capabilities.

Scalar group attributes use nearest-value inheritance. Collection records accumulate from implementation to inner group to outer group in source order. Each projected record retains its declaring level.

## Implementations

An implementation can define ID, version, architecture, stability, rollout percentage, license, main command, self-test, documentation directory, dependencies, commands, bindings, and retrieval methods. A package implementation delegates deployment to a distribution package manager. `ApplicableImplementations` applies only the known Zero Install runtime-version condition; it is not solver output.

## Runtime-version conditions

`if-0install-version` supports exact versions, exclusions, inclusive lower and exclusive upper bounds, open bounds, and union with `|`. Conditions inherit through containing groups. A missing runtime version leaves conditional applicability as null rather than selecting or rejecting the record.

## Commands and dependencies

Commands preserve path, arguments, `for-each`, working directory, runner, and inherited metadata. Requirements and restrictions preserve interface URI, version constraints, architecture constraints, importance, and bindings. Dynamic feed imports and distribution package resolution remain solver inputs.

## Capabilities

Windows-compatible URL-protocol and file-type capabilities are normalized into available protocols and extensions. Compiled integration arguments determine which categories the bootstrapper requests. When category selection is interactive or unknown, `AvailableProtocols` and `AvailableFileExtensions` remain evidence but `Protocols` and `FileExtensions` stay unresolved.

## URI identity

The canonical absolute feed URI is transformed by `FeedUri.PrettyEscape`: ASCII letters and digits remain unchanged, `/` becomes `#`, and every other UTF-16 code unit becomes `%` plus lowercase hexadecimal. This is not URL encoding. Non-BMP characters produce two escaped surrogate values.

## Retrieval recipes

Recipes preserve ordered archive, file, rename, remove, and copy-from steps. Unknown elements remain in `UnknownSteps` and make complete offline materialization unavailable. The parser does not silently skip an operation that could change the verified tree.
