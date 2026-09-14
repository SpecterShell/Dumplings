# Wise setup runtime

## Execution routes

The selected structural route determines which runtime interprets the command line and which component writes installed state.

| Route | First runtime | Installed-state owner |
| --- | --- | --- |
| `WiseSection/Msi` | Wise for Windows Installer launcher | nested MSI and Windows Installer |
| `WiseScript/Overlay` | WiseScript runtime | WiseScript, or a payload it executes |
| `ResourceLauncher/WiseScript` | vendor launcher, then WiseScript runtime | WiseScript or its selected nested payload |
| `NewExecutable/WiseScript` | 16-bit NE Wise runtime | WiseScript |

Do not apply MSI switches merely because a WiseScript package eventually launches an MSI. The outer process can consume, ignore, or forward the command line before the MSI starts.

## Silent installation

Classic WiseScript media commonly uses `/S` for silent execution. This is generic EXE behavior from the Wise runtime, not a WinGet default. It must be written explicitly when the artifact's route proves a compatible WiseScript runtime and silent behavior has not been contradicted by package-specific evidence.

The direct `WiseSection/Msi` route exposes MSI-style `/quiet`, `/passive`, `/norestart`, `/log`, and property arguments through its launcher. The install-location property must come from the nested MSI. An absent property means the parser omits the install-location switch.

The [NavigatorPlus 1.42 x86 and x64 files](https://www.fpmailing.co.uk/support/navigatorplus-support) are a different route. Their outer vendor launcher contains a WiseScript prerequisite package, and the script executes a nested Wise MSI launcher. Static control-flow and supplied package evidence show that `/S` does not turn the nested MSI into an unattended installation. The parser therefore returns only `interactive`, no installer switches, and `Wise.Installability.NestedMsiInteractiveOnly`.

## Elevation

An embedded WSE `Requested Execution Level=requireAdministrator` is strong evidence for `ElevationRequirement: elevationRequired`. It does not prove `Scope: machine`; a nested MSI can still omit an explicit `ALLUSERS=1` contract or choose scope dynamically.

For MSI-owned routes, explicit MSI properties and table evidence determine scope. When the MSI does not prove one scope, the parser leaves `Scope` unresolved even if the wrapper requests elevation. VM validation must then observe the real ARP hive and registry view.

## Architecture

The launcher machine type is bootstrapper architecture. Installed architecture comes from the nested MSI template and, when necessary, extracted application binaries. A 32-bit Wise launcher can install a 64-bit MSI or mixed payload. The parser keeps the outer PE version information separately and returns nested MSI architecture evidence under the common fields.

## Nested execution and external calls

`ExecuteProgram` records expose the configured path and arguments but are not executed. A nested executable is not assumed to own ARP merely because the script launches it. Dumplings requires structural MSI evidence or VM installed-state evidence.

Non-compiler-generated `CallDllFunction` records produce `Wise.Metadata.ExternalDllEffectsOpaque`. Their exported functions can change files, registry state, services, or installation decisions in ways that the static state projection cannot observe.

## Exit codes

The parser does not fabricate `InstallerSuccessCodes`. WiseScript wrapper exit-code propagation varies by route and nested process. Capture the process exit code during VM validation, including cancellation and successful silent installation where supported.
