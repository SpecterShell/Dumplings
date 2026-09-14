# dotNetInstaller format history

The upstream history separates physical storage changes from command-line behavior. A current-looking cabinet layout does not prove every current switch, and an old layout can be linked with later runtime capabilities.

| Boundary | Source-backed change | Parser behavior |
| --- | --- | --- |
| Early 1.x | `/q`, configuration XML, and one global cabinet set | `LegacyQuiet` can prove only the outer quiet switch; nested unattended behavior remains route-specific. |
| 2009-02-22 | ordered mixed XML children replace plural grouping nodes | Both grouped historical elements and current ordered elements are parsed. |
| 2009-04-25 | `/qb` and basic UI mode | `BasicUI` can expose `silentWithProgress` only when the token exists in the runtime. |
| 2009-10-29 | custom splash resources and `/nosplash` | Splash presence and switch capability are evaluated independently. |
| 2009-12-01 | files move into component-owned cabinet sets | Resource names can encode normalized component IDs. |
| 2009-12-09 | cabinet resource names gain `.CAB` | Named and extensionless cabinet profiles remain distinct. |
| 2010-07 | native and HTML launchers share the configuration model | HTM resources identify `LauncherKind: Html` without changing command semantics. |
| 2010-08-26 | `/noreboot` and revised reboot result handling | `RebootControl` can add `/noreboot`; earlier profiles cannot. |

## Verified release families

| Fixture family | Observed route | Capability evidence |
| --- | --- | --- |
| Historical 2007/2008 launchers | `ConfigurationOnly` | quiet-only runtime; no packaged component identity |
| Official 2.3 samples | `PerComponentCabinetsNamed` | `/q`, `/qb`, `/nosplash`, `/noreboot`, logging, and mode-specific component commands |
| Official 3.2.115 samples | `PerComponentCabinetsNamed` | stable current XML and cabinet behavior |
| CodeMeter Runtime 9.10 | `GlobalCabinetNamed` | current outer switches, one repeated WiX MSI, and authored nested commands that do not prove unattended modes |

The parser does not infer an exact release from cabinet names. `FormatGeneration` describes resource organization, `RuntimeCapabilityProfile` describes compiled switches, and `RuntimeVersion` requires the schema/token agreement described in [Architecture](architecture.md).

Historical attribute aliases remain valid. Current values take precedence over aliases when both exist. Unknown future XML attributes remain on raw attribute maps. Unknown component types remain structured evidence and cannot be promoted to an unattended route.

Mixed cabinet naming is accepted only when every set has valid part numbering and cabinet continuation metadata. It is a compatibility route, not a guessed release.

