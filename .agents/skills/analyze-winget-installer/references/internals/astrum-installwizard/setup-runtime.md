# Astrum InstallWizard setup runtime

The setup runtime turns compiled records into target-machine state. Static parsing establishes configured behavior; VM comparison establishes what a specific runtime does when elevation, conditions, dialogs, and external programs participate.

## Installation phases

Astrum actions can run at process startup, after each standard dialog, after installation, or during shutdown. Silent mode suppresses the interactive dialog sequence but does not erase actions whose timing still executes. Review `InteractiveOperations`, `ExecutedPayloads`, and conditions before treating the outer setup as the sole installer.

File extraction follows installation-item selection and conditions. Registry, shortcut, INI, text, and file operations can occur before or after payload copying. The generated uninstaller is a separate footer-owned member and is written only when uninstallation is enabled and its destination resolves.

## Silent behavior

Verified 2.x media accepts `/silent` and returns exit code `1` after successful installation. When the selected license dialog has the prohibit-silent flag, `/AcceptLicense` is also required; controlled Modern2 media refuses bare `/silent` with exit code `0` and leaves no partial state, while `/silent /AcceptLicense` installs fully.

Modern2 skips a compiled User Information dialog during `/silent`. This is confirmed by runtime inspection and VM installation. Early2 retains the builder documentation's interactive-only claim because no equivalent execution evidence exists. For 1.x, only a delimited `/SILENT` token in the native runtime option table establishes switch support, and the success code remains unprojected until validated for that generation.

The observed `/REVERT` token has an independent runtime flag, but its rollback behavior is not established and it is not exposed as a WinGet switch.

## Scope and elevation

The explicit uninstall hive is primary scope evidence. Requested execution level and resolved destination are fallbacks. HKLM and machine-protected destinations imply machine scope; HKCU and private user roots imply user scope. Mixed or conditional hives produce alternatives rather than a guessed scalar scope.

`requireAdministrator` or the compiled `RequireAdmin` option proves `ElevationRequirement: elevationRequired`. An `asInvoker` manifest does not prove that machine installation is usable unelevated. Controlled Modern2 media targeting HKLM and `%ProgramFiles(x86)%` refuses unelevated `/silent` with exit code `0` and no partial state, but installs when the caller is already elevated. The parser therefore reports caller elevation as required for structurally proven machine-protected writes and emits `Astrum.Elevation.CallerRequired`.

A require-administrator fixture started unelevated returns exit code `5` without installation. That refusal result is not a success code; successful 2.x installation still uses `1`.

## Registry view and application architecture

The x64-compliance option selects the native 64-bit registry view and 64-bit Program Files roots on 64-bit Windows even when the setup engine itself is x86. Otherwise the outer PE architecture provides the default view. Controlled x64 media writes its ARP row in the 64-bit view.

Application architecture comes from selected extracted EXE and DLL payloads, not from the setup stub. The parser materializes at most 32 relevant files under a 512 MiB aggregate bound, then reports architecture and native dependency evidence. Mixed payload evidence should remain explicit rather than forcing the outer architecture onto the manifest.

## Nested execution

“Execute program” and “Execute program and wait” can launch catalog payloads or external paths. Their command lines, timing, and conditions are returned, but child side effects remain opaque until the child is analyzed independently. A nested driver or prerequisite can own the visible ARP entry even when the Astrum outer setup also has identity metadata.
