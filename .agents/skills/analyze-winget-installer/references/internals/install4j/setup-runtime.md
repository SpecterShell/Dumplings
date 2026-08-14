# install4j setup runtime

[Back to install4j internals](overview.md).

## Native startup

The Windows launcher processes native command-line options, reads its overlay, decodes startup files, and locates a compatible Java runtime. Bundled-runtime media can unpack or use its private runtime. Runtime-independent media searches configured and system locations and can display an early native error before the Java installer starts.

The native stage also establishes the media path and logging context passed to the Java layer.

## Installer application selection

After Java starts, the runtime reads `i4jparams.conf`, builds the installer application object graph, and chooses GUI, console, or unattended mode. The selected mode affects screen traversal and user interaction, but does not by itself suppress actions.

Common command-line behavior includes unattended mode, response-file input or creation, target-directory override, logging, and installer-variable values. Package-specific code can reject or reinterpret these options.

## Screen and action traversal

Screens contain form components and ordered action lists. Action groups can nest other actions. The runtime evaluates conditions, mode restrictions, and failure policies before invoking each object.

```text
initialize installer context
  -> select installer application and mode
  -> visit screen or unattended handler
  -> evaluate action conditions
  -> execute elevated or normal action
  -> update variables and rollback stack
  -> continue, retry, skip, or abort
```

Standard actions have known contracts. Custom actions, scripts, listeners, and extension classes can perform arbitrary Java or native work.

## Privilege transitions

`RequestPrivilegesAction` can request elevation for administrator and normal users, update the installation directory after the scope decision, and fail if elevation is unavailable or rejected. An elevated action can also use a helper process while the main UI remains unelevated.

This is why install4j media can be machine-only, privilege-dependent dual-scope, or user-fallback. Static properties describe possible paths; VM testing proves the result for a specific command line and account state.

## Installation and rollback

The runtime installs files, registry entries, shortcuts, services, launchers, and associations through actions. Reversible actions register rollback work. An abort can leave effects created by custom code or external processes, because the runtime cannot automatically reverse arbitrary side effects.

## Maintenance and updates

The installed uninstaller starts another configured installer application. Update launchers and update descriptors can download or select replacement media. Overwrite behavior, existing-installation detection, and maintenance choices can depend on actions and application code rather than the outer file format.

## Exit behavior

Startup failures can come from the native launcher before Java starts. Runtime failures can come from validation, privilege acquisition, screens, actions, or custom code. Silent testing must record the process exit code and installed state; absence of visible UI is not enough to prove success.
