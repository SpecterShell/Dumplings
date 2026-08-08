# InstallShield InstallScript bytecode internals

[Back to InstallShield parser internals](overview.md).

## Binary structure

InstallScript-only media adds a project configuration and a compiled script. The parser decodes modern INX catalogs and instructions into a bounded structural IR and abstractly interprets source-backed language operations. Imported DLLs, registry APIs, payloads, and child processes are never invoked: calls are recorded as static evidence and only documented effects are projected.

```text
Extracted InstallScript media
+-- setup.ini
|   `-- [Startup]
|       +-- ProductGUID  -> PRODUCT_GUID and default uninstall-key name
|       +-- Product      -> IFX_PRODUCT_NAME default
|       +-- AppName      -> older PackageForTheWeb project-name fallback
|       `-- CompanyName  -> IFX_COMPANY_NAME default
+-- setup.inx / setup.ins
|   +-- CRC/version prefix
|   +-- copyright marker within the first 512 decoded bytes
|   `-- bounded instruction and call evidence
|       +-- arithmetic, comparison, string, branch, RESULT, and member state
|       +-- RegDBSetItem / RegDBSetKeyValueEx / generated registry wrappers
|       +-- process, file, and shortcut API arguments
|       `-- Software\Microsoft\Windows\CurrentVersion\Uninstall\
+-- StringTable_0xLLLL.ips
|   `-- localized key/value resources used by __LoadString wrappers
`-- optional setup.iss
    `-- silent dialog responses; not authoritative ARP version metadata

MaintenanceStart default projection
+-- HKCU or HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\{ProductGUID}
|   +-- ProductGuid      = PRODUCT_GUID
|   +-- DisplayName      = IFX_PRODUCT_NAME
|   +-- DisplayVersion   = IFX_PRODUCT_VERSION       (runtime; unresolved)
|   +-- Publisher        = IFX_COMPANY_NAME
|   +-- InstallLocation  = TARGETDIR                 (runtime; unresolved)
|   `-- UninstallString  = UNINSTALL_STRING          (runtime; unresolved)
`-- visibility/scope depend on ALLUSERS and ADDREMOVE_SYSTEMCOMPONENT
```

```text
Modern or Stirling-era decoded setup.inx
Offset  Size      Field
------  --------  --------------------------------------------------------
0x00    4         CRC/signature-like value; decoded files commonly use aLuZ
0x04    2         compiler/header value, uint16 LE
0x06    74        NUL-padded InstallShield/Stirling copyright field, ASCII
0x50    24        reserved/observed header data
0x68    20        five absolute uint32 LE offsets
                    offset[2] -> type/function/label catalog
                    offset[4] -> end of instruction segment

Catalog at offset[2]
+-- uint16 TypeCount
|   `-- repeated type-field records
+-- uint16 FunctionCount
|   `-- type, return type, DLL/name strings, entry label, parameters
+-- uint16 LabelCount
|   `-- repeated uint32 absolute instruction offsets
`-- function bodies
    +-- observed uint16 body prefix
    +-- 0x0022 function-start record
    +-- tagged, variable-length instruction records
    `-- 0x0026 function-end record

Call instruction 0x0020/0x0021
+-- uint16 FunctionPrototypeIndex
+-- uint16 ArgumentCount
`-- repeated tagged operands
    +-- 0x00: byte integer
    +-- 0x06: uint16 length + ASCII string
    +-- 0x07: int32 LE
    `-- 0x02..0x0A: variable, local, or label references

Property proxy registration 0x003B (official 11.5 compiler observation)
+-- uint16 EncodedCount = 3 (destination plus two operands)
+-- tagged destination: runtime-backed variable
+-- tagged int32 GetterFunctionIndex
`-- tagged int32 SetterFunctionIndex
    `-- normally followed by numeric-slot = RESULT, storing the opaque handle
```

## Parsing behavior

The reader validates every catalog count, offset, string, operand, instruction count, and function boundary. Modern core and extension records are structurally decoded through their tagged operand framing. The abstract interpreter evaluates source-backed arithmetic, comparisons, string operations, RESULT-slot operations, generated wrappers, and structure-member state. InstallShield 11.5 differential builds ground `AddressOf`, primitive `Indirect`, pointer-parameter prologues, and prototype flag `0x02` (`BYREF`): referenced structure snapshots survive function-frame changes, primitive references can be read without creating a host pointer, and callee assignments are written back to the caller. The same official compiler output grounds `Handler(eventId, functionIndex)`, `ExecuteHandler(eventId)`, and inline `try`/`catch`/`endcatch` framing. Normal-path analysis skips exception-only catch bodies; imported calls are not executed, so catch-only effects remain conditional rather than being promoted to ARP evidence. `UseDLL` and `UnUseDLL` produce `DllOperations` containing the requested module path, but the DLL is never loaded and its exported functions remain opaque. Official 11.5 compiler output also grounds opcode `0x003B` as a runtime property-proxy registration: `PropertyHandlers` exposes the target variable, paired getter/setter functions, and compiler-generated handle slot. The parser does not invoke those handlers or guess their process-dependent initial values. It intentionally does not call `0x003B` `AskOptions`; historical decompilers disagree on that label.

## Metadata projection

Direct `RegDBSetKeyValueEx`, legacy registry setters, and compiler-generated `_RegSetKeyValue` wrappers produce `RegistryWrites`. Complete HKCR writes are converted to `Protocols`, `FileExtensions`, `ProtocolAssociations`, and `FileExtensionAssociations`; localized `.ips` resources are resolved before association matching. `RegDBSetItem` produces `RegistryItems` and can override built-in `DisplayName`, `DisplayVersion`, `Publisher`, `InstallLocation`, `ProductGuid`, and `SystemComponent` before `MaintenanceStart`. `CreateProcess`, `LaunchApp*`, `ShellExecute*`, file APIs, and shortcut APIs produce typed evidence without performing the operation. `CreateRegistrySet` and `CreateShellObjects` select the independently parsed media-database records described above. Selection and records are reported separately so conditional project data is not mistaken for an executed effect.

Older generated scripts may expose only a `program` entry point which delegates to `ISRT._ShowWizardPages`. Official InstallShield framework source shows that the runtime calls the exported `IfxOnShowWizardPages` function, which then selects first-install, maintenance, or update UI. Dumplings follows that callback back into ordinary INX functions, preserves nested call order, and reports the result as `DialogTraces.Source: FrameworkCallback`. It does not treat the runtime function as an opaque data table.

## Limits and gaps

Framework reconstruction remains incomplete when `MODE`, `MAINTENANCE`, feature selection, or BACK/NEXT branches can suppress, repeat, or replace pages. Completion choices such as `SdFinish` versus `SdFinishReboot` remain alternatives, and the generated response template requires review against a VM-recorded file. The Unitronics U90 Ladder 6.6.45 PackageForTheWeb/Stirling fixture exercises this path: its fresh-install sequence exposes `SdWelcome`, `SdLicense`, `SdAskDestPath`, `SdSelectFolder`, and `SdStartCopy`, while maintenance exposes `SdWelcomeMaint` and `SdComponentTree`. The SHARP Pen Software 3.9 sample is MSI-bearing InstallShield media and does not add a distinct InstallScript behavior to the focused fixture set.

Other unknown extension semantics remain in `UnsupportedOpcodes` and are never assigned invented behavior. Limits bound recursion, loops, paths, calls, instructions, value alternatives, and emitted effects. `Get-InstallShieldInstallScriptDialogTrace` follows entry-point calls and generated wrapper literals, grouping `OnFirstUIBefore` with `OnFirstUIAfter` and maintenance equivalents. Mutually exclusive license and completion dialogs remain alternatives rather than being flattened into an invented sequence.

For scrambled INX generations, each byte is decoded from its absolute file offset as `ROR8(encoded XOR 0xF1, 2) - (offset modulo 71)`. The parser validates the copyright marker in the decoded header before accepting the transform. It reports only documented default ARP values and labels custom script assignments as unresolved.
