# dotNetInstaller setup runtime

## Startup and configuration routing

The launcher parses its command line, establishes UI level and logging, loads the embedded or `/ConfigFile` document, resolves reference configurations, filters configurations for locale and OS, then runs each applicable install configuration. The parser models this order without using the analysis host as the target machine.

## UI mode fallback

Every command family uses the same source-backed selection order:

```text
full request:   full
basic request:  basic -> silent -> full
silent request: silent -> basic -> full
```

A fallback to `full` does not prove unattended behavior. The parser marks each route with `UsesModeFallback` and `IsUnattendedRouteProven`. `NestedInstallModes` contains only modes proven across every default-selected component. `InstallModes` describes outer runtime capabilities and must not be used alone for WinGet authoring.

## Command-line capabilities

The parser searches exact null-terminated tokens in non-resource PE sections.

| Profile | Proven outer behavior |
| --- | --- |
| `LegacyQuiet` | `/q` |
| `BasicUI` | `/q`, `/qb` |
| `SplashControl` | `/q`, `/qb`, `/nosplash` |
| `RebootControl` | `/q`, `/qb`, `/nosplash`, `/noreboot` |
| `Unknown` | no safe unattended suggestion |

Logging is suggested only when both `log` and `logfile` tokens exist. `/ComponentArgs` is returned as a capability but is not authored automatically because one blanket value can corrupt mixed component types.

## Downloads and references

Download records identify intended URLs, local names, hash or size evidence, and UI behavior. They do not make remote bytes available to static parsing. Callers can supply already acquired reference XML and companion payloads. The parser never performs network retrieval.

## Completion commands

After component execution, a configuration can run `complete_command`, `complete_command_basic`, or `complete_command_silent`. The same mode fallback applies. These commands can launch the application or perform arbitrary side effects after a silent install. A completion command selected for silent mode produces a risk diagnostic even when component routes are unattended.

## Scope and elevation

`administrator_required="true"` and a `requireAdministrator` PE manifest are elevation evidence. A selected nested MSI can provide scope evidence. Disagreement among configurations or target-state-dependent routes remains conditional. The parser does not convert a prerequisite installed check into package scope.

## Reboot and exit behavior

Configuration and component fields control reboot requirements, mandatory reboot, auto-continue, run-on-reboot commands, error continuation, and reload behavior. `/noreboot` suppresses the requested reboot only on runtimes that expose the token. Child exit-code handling and arbitrary completion commands can alter the final outcome, so nonstandard success codes require artifact-specific or VM evidence.

