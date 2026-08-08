# InstallShield MSI custom-action internals

[Back to InstallShield parser internals](overview.md).

## Binary structure

Basic MSI and InstallScript MSI projects can also compile authored InstallScript custom actions into the MSI `Binary` table. The physical payload and dispatch metadata are separate: `CustomAction.Target` is commonly an opaque `fN` export, while `IsConfig.ini` supplies the authored function name.

```text
MSI database
+-- Binary.Name = "ISSetup.dll"
|   `-- PE image
|       `-- overlay: "ISSetupStream"
|           +-- Setup.inx              compiled InstallScript bytecode
|           +-- IsConfig.ini
|           |   `-- [fN] Function=<authored function name>
|           +-- StringLLLL.txt         localized __LoadString resources
|           `-- InstallScript runtime support files
`-- CustomAction
    +-- Source = "ISSetup.dll"
    +-- Target = "fN"
    `-- Action + sequence tables        invocation and condition evidence

Resolution chain
CustomAction.Target "f1" -> IsConfig.ini [f1].Function
                         -> bounded emulation of only that Setup.inx function
```

## Parsing behavior

Resolve each `CustomAction.Target` through `IsConfig.ini`, then emulate only the selected InstallScript function and its bounded call graph. Keep action-sequence conditions and physical binary extraction separate from emulated effects.

## Metadata projection

Project registry, process, file, dialog, and ARP effects only when the selected function produces source-backed static evidence. Retain the MSI action name, function mapping, and condition with each result.

## Limits and gaps

`ISVerifyScriptingRuntime`, `ISInstallScriptAction`, `ISScriptFile`, and the `ISInstallScript*` table/action families classify an InstallScript MSI. `Source=ISSetup.dll` plus an `fN` target proves a compiled custom action but does not by itself distinguish Basic MSI from InstallScript MSI.
