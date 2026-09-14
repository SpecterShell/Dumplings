# CreateInstall setup runtime

## Runtime phases

The native launcher maps the `.gentee` section, restores a packed GE program when required, initializes globals and linked imports, and enters generated project code. That code evaluates setup conditions, installs selected GEA groups, performs configured system operations, registers uninstall state, and may execute child payloads or launch the application. The generated uninstaller uses the same architecture to replay removal actions and the installation log.

The parser models compiled intent rather than running this sequence. Ordering matters for final state: custom registry calls after the generated setup body can replace built-in ARP values, and a later child executable can introduce effects that are absent from the outer program.

## Silent installation

CreateInstall does not have a safe family-wide switch. The project variable `silentpar` defines the accepted argument. A resolved nonempty value produces `InstallerSwitches.Silent` and `InstallerSwitches.SilentWithProgress` with that exact spelling and produces all three modes: `interactive`, `silent`, and `silentWithProgress`. An empty or unresolved value produces only `interactive` and no switch fields.

The official 5.9.0 builder setup is interactive-only in parser evidence. Available official builders from 5.19.1 through 8.11.2 compile `-silent`. A controlled current setup invoked with `-s` still displayed the wizard, demonstrating why aliases must not be guessed.

The same switch is used for WinGet's silent and silent-with-progress fields because the runtime's authored silent route controls UI suppression rather than exposing two distinct progress modes. Confirm the actual UI and exit code in the VM for the package artifact before submission.

## Elevation and scope

The built-in legacy Add/Remove routine writes through runtime registry context. Later `addremoveex` and `addremoveext` calls also carry a current-user Boolean. The parser combines that argument with the PE requested execution level and deterministic custom registry writes.

An explicit HKCU uninstall record proves user scope. An explicit HKLM record proves machine scope. `SHCTX` proves both possible roots but not which one a particular launch will choose, so `Scope` remains null and `SupportedScopes` contains both. A `requireAdministrator` PE manifest can establish machine scope when no deterministic ARP record exists. An `asInvoker` manifest alone does not prove user scope because the process may still write to a user-writable custom destination or launch an elevated child.

CreateInstall generally uses an x86 setup runtime. Registry view follows the executing runtime unless a custom registry operation selects another view. Program Files macros resolve according to the target route, so `%ProgramFiles(x86)%` is valid output for the common x86 runtime even on a 64-bit OS.

## Child processes and prerequisites

Configured EXE and MSI runs can be synchronous or asynchronous and can be conditional. `runmsiex` can add quiet/passive, restart, and logging options to the nested MSI command. Those options describe the child invocation selected by the CreateInstall project; they do not prove that the outer setup itself has the same switch or return-code behavior.

Visual C++ prerequisite checks can inspect several generations and architectures, combine results, set a macro, show a failure message, and abort or route later operations. Bundled runtime installers may execute only when the condition is true. VM validation should test a clean machine when a prerequisite affects installability.

Downloads are runtime network operations. A package can contain no GEA payload and still install downloaded or generated content. Static analysis reports the source and destination but does not follow the URL because current server state is not part of the installer artifact.

## Process results

No family-wide success-code override is authored by the parser. Record the exact process exit code during unattended VM validation. A successful install, a prerequisite refusal, a user cancellation, and a child-process failure can take different paths even when the outer runtime returns a conventional value.

## Dynamic validation boundary

VM validation is required when an unresolved `@function`, user dialog, external DLL, registry or filesystem probe, download, nested installer, or previous-version state affects ProductCode, scope, architecture, silent completion, dependencies, or installed files. Capture before-install, after-install, and after-first-run installed state as appropriate. Compare the actual visible ARP key, view, values, install location, associations, services, tasks, and child effects with the parser output rather than treating a zero exit code alone as success.
