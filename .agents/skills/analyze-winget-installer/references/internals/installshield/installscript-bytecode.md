# InstallShield InstallScript bytecode internals

[Back to InstallShield internals](overview.md).

InstallScript is a compiled installation language hosted by the InstallShield runtime. A shipped setup normally contains project bytecode, runtime libraries, localized string tables, media catalogs, and a small configuration file. The bytecode does not contain the whole installer: file transfer, registry sets, feature selection, dialogs, and maintenance also depend on the runtime and media database.

## Runtime layers

```text
setup.exe
  -> reads Setup.ini and selects language/media
  -> loads InstallShield runtime (ISRT)
  -> loads InstallShield framework library (IFX)
  -> loads project setup.inx or setup.ins
  -> links optional object libraries (OBL) while building the final program
  -> invokes framework and project event handlers
  -> transfers files from data*.hdr/data*.cab
  -> records maintenance state and uninstall information
```

The project program calls two broad classes of functions:

- InstallScript functions compiled into the project or an object library.
- Native runtime functions supplied by ISRT, IFX, or a project DLL.

The second class is an ABI boundary. Its behavior may depend on the operating system, installer mode, feature state, registry, prior installations, or native code that is absent from the bytecode.

## Shipped program files

| File | Role |
| --- | --- |
| `setup.inx` | Compiled project program used by most later InstallScript generations. |
| `setup.ins` | Older compiled script or action stream. The layout is not interchangeable with modern INX. |
| `.obl` authoring libraries | Named compiler object modules consumed while building the final linked program. |
| `StringTable_0xLLLL.ips` | Locale-specific string resources, where `LLLL` is a language identifier. |
| `setup.iss` | Recorded answers for response-backed dialogs. It is data, not program bytecode. |
| `Setup.ini` | Bootstrap configuration and initial product variables. |
| `data*.hdr` / `data*.cab` | Project media catalog and payloads referenced by runtime operations. |

A file may be stored directly beside `setup.exe`, in the launcher overlay, in PackageForTheWeb media, in `data*.cab`, or in `Binary.ISSetup.dll` inside an MSI. The enclosing container does not determine the bytecode generation.

## Compiled format families

The first bytes identify materially different program databases:

```text
Offset  Bytes                         Family       Notes
------  ----------------------------  -----------  ----------------------------
0x00    B8 C9 0C 00                   old INS      event/action representation
0x00    48 4F F3 C9                   OBS          fixed catalog header
0x00    61 4C 75 5A  ("aLuZ")        aLuZ         packed modern INX header
0x00    6B 55 74 5A  ("kUtZ")        kUtZ         related encoded generation
0x00    70 4F 64 41  ("pOdA")        OBL          object-library container
```

These names describe physical program layouts, not InstallShield product releases. A newer builder can carry compatibility runtimes or consume an older library, so release identity and bytecode family must be recorded separately.

### Old INS

The old INS stream is sequential rather than offset-table driven. A malformed record cannot always be skipped because the next action has no independent length. Decoding therefore stops at the first action whose framing is not known.

```text
Offset  Size      Field
------  --------  --------------------------------------------------
0x00       4      B8 C9 0C 00
0x04       9      legacy header fields
0x0D       2      copyright/info length, uint16 little-endian
...        var    copyright/info bytes
...        2      event count
...        var    global string and number catalogs
...        var    structure catalog
...        var    function and DLL prototype catalog
...        var    event records
```

Each event starts with a reserved word and an action count. Actions begin with a uint16 action ID. Most actions use tagged operands; some control-flow, call, function-prolog, and variable-argument actions have dedicated framing.

```text
Event
+----------------------+
| Reserved      uint16 |
+----------------------+
| ActionCount   uint16 |
+----------------------+
| ActionId      uint16 | repeated ActionCount times
+----------------------+
| Action payload       | action-specific
+----------------------+

Tagged operand
  high nibble 0x3/0x4 -> numeric variable or int32 constant
  high nibble 0x5/0x6 -> string variable or uint16-length string constant
```

Known assignment, branch, call, return, arithmetic, and property actions can be projected into the common instruction model. The original action ID must still be retained because normalization loses generation-specific opcode identity.

### OBS

OBS uses a fixed `0x100`-byte header. It is an object module consumed by the InstallScript linker, rather than the final setup program. Header fields identify compiler data and absolute file offsets for strings, variables, prototypes, typedefs, address fixups, debug records, and basic blocks. Catalog counts and offsets are little-endian. Strings use length-prefixed records.

```text
OBS object module
+0x000   4     magic 48 4F F3 C9
+0x004  12     compiler version, NUL-padded ASCII
+0x010  80     copyright, NUL-padded ASCII
+0x062   2     basic-block count, uint16 LE
+0x074   2     global numeric-variable count, uint16 LE
+0x07C   4     string-variable table offset, uint32 LE
+0x080   4     variant-variable table offset, uint32 LE
+0x084   4     external-symbol table offset, uint32 LE
+0x088   4     prototype table offset, uint32 LE
+0x08C   4     typedef table offset, uint32 LE
+0x090   4     address-resolution table offset, uint32 LE
+0x094   4     optional debug table offset, uint32 LE
+0x0D8   4     basic-block offset table, uint32 LE
+0x100  ...    catalogs, basic blocks, and instruction records
```

Prototype flags distinguish DLL, internal, predefined, exported, calling- convention, property, and variable-argument records. The address-resolution table contains a count followed by `(type:uint8, offset:uint32)` records. These are locations within one OBS member that the build-time linker must fix. They are not calls to another OBL member and do not form an OBL-level relocation map.

### aLuZ and kUtZ

The aLuZ generation uses a packed 124-byte header. It contains absolute offsets to variables, prototypes, typedefs, basic blocks, and debug data. The executable instruction region is bounded by header offsets; it is not the remainder of the file.

```text
Decoded modern INX
Offset  Size  Field
------  ----  ----------------------------------------------------------
0x00       4  format marker or decoded signature
0x04       2  compiler/header value, uint16 little-endian
0x06      74  NUL-padded copyright field
0x50      24  generation-specific header data
0x68      20  five absolute uint32 little-endian offsets
                 offset[2] -> type/function/label catalog
                 offset[4] -> end of instruction segment
```

The catalog reached through `offset[2]` has this general organization:

```text
+---------------------------+
| TypeCount        uint16 LE|
+---------------------------+
| Type records              | repeated
+---------------------------+
| FunctionCount    uint16 LE|
+---------------------------+
| Function/prototype records| repeated
+---------------------------+
| LabelCount       uint16 LE|
+---------------------------+
| Label offsets    uint32 LE| repeated
+---------------------------+
| Function bodies           |
+---------------------------+
```

kUtZ belongs to the same broad compiled-program lineage but requires its own header and decoding profile. Similar instruction bytes do not make header offsets interchangeable.

### OBL libraries

An OBL file is a directory of named compiled members:

```text
Offset  Size      Field
------  --------  -------------------------------------------
0x00       4      magic 70 4F 64 41 ("pOdA")
0x04       4      format value, observed as uint32 value 1
0x08       4      member count, uint32 little-endian
...        2      member-name length, uint16 little-endian
...        var    member-name bytes
...        4      member offset, uint32 little-endian
...        4      member length, uint32 little-endian
...        var    repeated directory records and member data
```

Member offsets point to bounded compiler inputs. A library directory is not an instruction stream and must not be decoded as one. Each recognized member can be parsed independently, including its exported prototypes, external variables, member-local fixups, basic blocks, and actions.

Official 11.5 and 2026 builder libraries use this same container and carry OBS members reporting compiler version `v3.99.002`. The OBL catalog itself contains no cross-member symbol or runtime-loading table. InstallShield resolves the objects while linking the final INX, so installer analysis should prefer that linked program. Inspecting OBL members is useful for builder research and for understanding library behavior, but combining them by name would invent linkage that is not present in the file.

## Byte scrambling

Some INX generations store scrambled bytes. The observed transform is indexed by the absolute file offset:

```text
decoded = ROR8(encoded XOR 0xF1, 2) - (absoluteOffset modulo 71)
```

The subtraction wraps to one byte. A successful transform must produce the expected copyright/header structure and valid catalog ranges. Applying the transform merely because a file is named `setup.inx` creates convincing but invalid offsets.

## Program database

The compiled file contains more than opcodes. It describes the program's type system and linkage:

- Global variables and runtime-backed variables.
- Primitive and structure type definitions.
- Function prototypes, parameters, return types, and flags such as BYREF.
- Imported module and function names.
- Function entry labels and general labels.
- Basic-block and debug/source mappings when retained by the build.
- Encoded instructions and typed operands.

Function indexes, label indexes, type indexes, and string indexes belong to their respective catalogs. They are not byte offsets unless the format record explicitly says so.

## Instruction framing

Modern function bodies begin and end with structural records. Calls carry a prototype index and a typed argument list:

```text
Function body
  +-- body prefix, generation-specific
  +-- 0x0022 function-start record
  +-- variable-length instruction records
  `-- 0x0026 function-end record

Call instruction 0x0020 or 0x0021
  +-- FunctionPrototypeIndex, uint16 little-endian
  +-- ArgumentCount, uint16 little-endian
  `-- tagged operands
      +-- 0x00: byte integer
      +-- 0x06: uint16 length followed by ANSI string
      +-- 0x07: int32 little-endian
      `-- other tags: variable, local, member, reference, or label
```

The opcode number alone is insufficient to determine instruction length. The generation's operand tags and catalog references define the framing.

Official InstallShield 11.5 compiler output also shows opcode `0x003B` as a runtime property-proxy registration:

```text
0x003B property proxy
  +-- encoded operand count, normally 3
  +-- runtime-backed destination variable
  +-- getter function index
  `-- setter function index
      `-- runtime returns an opaque handle through RESULT
```

Historical decompilers have assigned unrelated names to this opcode. Controlled builder output is stronger evidence than a mnemonic copied from one decompiler.

## Values, frames, and references

InstallScript has global variables, function-local variables, parameters, structures, runtime properties, and the special `RESULT` state. Calls create a new frame, but BYREF parameters can modify caller-owned values. `AddressOf` and indirection operate on InstallScript references, not native host pointers.

Compiler-generated wrappers commonly copy a runtime result into a numeric or string slot immediately after a call. Ignoring this convention loses branch conditions and property values even when the called operation is understood.

## Control flow and handlers

The language provides ordinary branches and calls plus installer-specific event dispatch. Official compiler output grounds records equivalent to:

```text
Handler(eventId, functionIndex)
ExecuteHandler(eventId)
try
  ... normal-path instructions ...
catch
  ... exception-path instructions ...
endcatch
```

The framework registers and invokes handlers around setup phases. A project may expose named handlers such as `OnFirstUIBefore`, `OnFirstUIAfter`, maintenance handlers, update handlers, or only a `program` entry that delegates to `ISRT._ShowWizardPages`. The framework then calls `IfxOnShowWizardPages`, which selects the actual first-install, maintenance, or update path.

Running every function is not equivalent to running setup. Helper functions, exception handlers, uninstall branches, and unused code can contain destructive or unrelated effects.

## Dialogs and response files

InstallScript dialogs are runtime calls such as the `Sd*` wizard family. The project controls order and branching; IFX implements the page. Some dialog calls read values from `setup.iss` during silent mode.

```text
record mode (-r)
  -> interactive dialog receives user input
  -> runtime writes section and values to setup.iss

silent mode (-s)
  -> project reaches the same response-backed dialog
  -> runtime reads the matching setup.iss section
  -> missing or incompatible data can stop, exit, or reveal UI
```

A syntactically valid response file can still target the wrong release, language, setup type, or maintenance scenario. Some projects avoid response- backed dialogs in silent mode and therefore support unattended installation without an external file; most traditional InstallScript projects do not.

## Runtime variables and localization

`Setup.ini` seeds values such as `PRODUCT_GUID`, `IFX_PRODUCT_NAME`, and `IFX_COMPANY_NAME`. Other variables, including `TARGETDIR`, feature state, maintenance mode, and calculated product version, are initialized or changed at runtime.

Localized IPS tables supply strings to generated resource-loading wrappers. One compiled registry write can therefore produce different DisplayName, Publisher, protocol, or file-association text for different languages.

Dynamic expressions such as script callbacks, native DLL results, target-state queries, and code-generated paths have no single literal value in the compiled program.

## Media and system operations

InstallScript built-ins cover:

- Feature and component selection.
- File transfer and deletion.
- Registry roots, keys, values, and named registry sets.
- Shell folders, shortcuts, protocols, and file associations.
- Process creation and shell execution.
- DLL loading and imported native calls.
- Services, environment, fonts, INI files, and other system configuration.

`CreateRegistrySet` and `CreateShellObjects` select records stored in the media database. Their arguments identify authored data; the actual values and owning components live in `data1.hdr`. Component-associated records are normally applied while that component transfers, even when no explicit script call names them.

Native DLL exports are opaque to the InstallScript program database. `UseDLL` can prove that a DLL is loaded and a call record can prove its arguments, but the export's side effects require inspection of that DLL or runtime observation.

## Maintenance and Apps & Features

The framework function `MaintenanceStart` creates the default InstallScript uninstall contract. Its inputs include project identity and runtime variables:

```text
HKCU or HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\{ProductGUID}
  ProductGuid      <- PRODUCT_GUID
  DisplayName      <- IFX_PRODUCT_NAME
  DisplayVersion   <- IFX_PRODUCT_VERSION
  Publisher        <- IFX_COMPANY_NAME
  InstallLocation  <- TARGETDIR
  UninstallString  <- runtime-generated maintenance command
```

`ALLUSERS` and installation context influence HKCU versus HKLM. The `ADDREMOVE_SYSTEMCOMPONENT` state can hide the entry. Project code can call `RegDBSetItem`, write the uninstall key directly, create additional entries, or suppress the default registration.

A `ProductGUID` in `Setup.ini` is project identity. It becomes ARP identity only when the reachable framework or project behavior registers the corresponding uninstall key.

## Static-analysis boundaries

Reliable static interpretation requires bounded catalogs, valid instruction framing, source-backed opcode semantics, separate scenario entry points, and three-valued conditions. Unknown native calls, unsupported opcodes, runtime properties, and target-machine queries must remain unresolved.

Useful evidence includes literal registry operations, event call graphs, dialog order, media-set selection, process launches, and localized alternatives. It does not prove that every path executes, that a response file matches a particular machine, or that opaque native code has no additional side effects.
