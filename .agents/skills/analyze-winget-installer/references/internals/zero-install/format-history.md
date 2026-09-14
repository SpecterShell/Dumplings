# Zero Install format history

## Configuration profiles

`ZeroInstallFormatCatalog.psd1` separates storage profiles from feature introduction versions.

| Profile | Observed releases | Storage |
| --- | --- | --- |
| `LegacyGenericBootstrapper` | 2.11.0 through 2.11.5 | source-backed CLR type identity, no customizable configuration resource |
| `EmbeddedConfig3Mode` | 2.11.6 through 2.20 | fixed UTF-8 lines for URI, name, and mode |
| `EmbeddedConfig5Mode` | 2.21 | fixed lines with additional integration fields |
| `EmbeddedConfig5Integrate` | 2.22 | fixed lines with separate application and integration arguments |
| `EmbeddedConfig6AppFingerprint` | 2.23.0 | six fixed lines with self-update URI and application fingerprint |
| `EmbeddedConfig6KeyFingerprint` | 2.23.1 through 2.24.0 | six fixed lines with self-update URI and key fingerprint |
| `EmbeddedConfig7` | 2.24.1 through 2.24.7 | seven fixed lines adding customizable store-path policy |
| `ConfigIni` | 2.24.8 through 2.25.2 | `ZeroInstall.config.ini` |
| `BootstrapConfigIni` | 2.25.3 and later | `ZeroInstall.BootstrapConfig.ini` plus adjacent basename INI override |

Exact profile names are executable parser data; use the catalog rather than inferring them from line count in documentation.

## Sidecar precedence

```text
2.11.6-2.11.7: embedded fixed lines
2.11.8-2.24.7: embedded fixed lines -> qualifying appSettings in EXE.config
2.24.8-current: embedded INI -> adjacent EXE-basename.ini replacement
```

## Runtime behavior boundaries

| Version | Behavior introduced or removed |
| --- | --- |
| 2.11.0 | generic deployment `--silent` and `--verysilent` |
| 2.11.6 | customizable bootstrap config and `--content-dir` |
| 2.11.8 | adjacent appSettings overrides |
| 2.14.5 | legacy generic deployment silent aliases removed |
| 2.21.0 | desktop-integration ARP entry |
| 2.23.0 | app-bootstrapper `--silent`; GUI retains progress |
| 2.23.1 | `--machine` and `--no-integrate` |
| 2.23.3 | ARP display-name suffix removed |
| 2.23.9 | `--prepare-offline` |
| 2.24.0 | ARP Publisher, `--refresh`, GUI `--background`, and GUI `--verysilent` |
| 2.24.6 | embedded content and split target/runtime version options |
| 2.24.7 | `--wait` |
| 2.24.8 | INI configuration, `--store-path`, and `--integrate-args` |
| 2.25.3 | current embedded INI resource name |
| 2.25.4 | `estimated_required_space` |
| 2.25.12 | ARP modify command and `NoModify=0` |
| 2.27.5 | target `--feed` separated from runtime `--0install-feed` |

When PE version is absent, a profile proves a feature only if its complete version interval lies on one side of the boundary. Otherwise the feature remains unresolved.
