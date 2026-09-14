# MicaSetup binary format

## Container stack

```text
setup.exe
+-- IMAGE_DOS_HEADER and PE signature
+-- COFF and optional headers
+-- section table
+-- IMAGE_COR20_HEADER
|   +-- metadata directory
|   `-- managed resources directory
+-- CLR metadata streams
|   +-- #~ tables
|   +-- #Strings, #Blob, #GUID, and #US heaps
|   `-- MethodDef bodies containing generated CIL
+-- managed resource blob
|   `-- length-prefixed <assembly>.g.resources
|       `-- ResourceManager records
|           +-- resources/setups/publish.7z
|           `-- resources/setups/uninst.exe
`-- optional certificate table
```

All PE and CLR integers are little-endian. RVAs are translated through the PE section table before file access. Resource-relative and metadata-relative offsets are checked with overflow-safe arithmetic before allocation or seeking.

## CLR header

`IMAGE_OPTIONAL_HEADER.DataDirectory[COM_DESCRIPTOR]` identifies `IMAGE_COR20_HEADER`.

```text
Offset  Size  Field
------  ----  ---------------------------------------------
0x00       4  cb, CLR header size
0x04       2  MajorRuntimeVersion
0x06       2  MinorRuntimeVersion
0x08       8  MetadataDirectory { RVA:u32, Size:u32 }
0x10       4  Flags
0x14       4  EntryPointToken or native RVA
0x18       8  ResourcesDirectory { RVA:u32, Size:u32 }
...            remaining CLR data directories
```

The metadata reader uses the Assembly, CustomAttribute, TypeDef, TypeRef, MemberRef, MethodDef, Property, MethodSemantics, ManifestResource, and related signature tables. User strings used by generated assignments come from `#US`; names and qualified type identities come from `#Strings`.

## ManifestResource linkage

An embedded `ManifestResource` row has a nil `Implementation` handle. Its `Offset` is relative to the start of the CLR managed-resource directory. A four-byte length precedes the nested resource bytes.

```text
ResourcesDirectory + ManifestResource.Offset
+-------------------------------+
| ResourceLength:u32 LE         |
+-------------------------------+
| ResourceData[ResourceLength]  |  .g.resources stream
+-------------------------------+
```

The parser accepts only embedded resource rows whose metadata name ends in `.g.resources`. It validates the outer length against both the CLR resource directory and physical stream.

## ResourceManager stream

MicaSetup's current artifacts use ResourceManager runtime version 2. Offsets below are relative to the nested `.resources` stream.

```text
Offset  Size                         Field
------  ---------------------------  ------------------------------------------
0x00       4                         Magic:u32 = 0xBEEFCACE
0x04       4                         ResourceManagerHeaderVersion:i32
0x08       4                         BytesToSkip:i32
0x0C       BytesToSkip               reader/set type metadata
...        4                         RuntimeVersion:i32 = 2
...        4                         ResourceCount:i32
...        4                         TypeCount:i32
...        variable                  user type names
...        0..7                      padding to 8-byte relative alignment
...        ResourceCount * 4         name hashes:i32
...        ResourceCount * 4         name positions:i32
...        4                         DataSectionOffset:i32
...        variable                  name section
...        variable                  data section
```

Each name position is relative to the name section. The signed data position stored after the UTF-16LE resource name is relative to the data section.

```text
Name record
+-------------------------------+
| NameByteLength: 7-bit int     |
+-------------------------------+
| UTF-16LE name bytes           |
+-------------------------------+
| DataPosition:i32 LE           | -> data section
+-------------------------------+

Stream or byte-array data record
+-------------------------------+
| TypeCode: 7-bit int           | 32 = ByteArray, 33 = Stream
+-------------------------------+
| Length:i32 LE                 |
+-------------------------------+
| Data[Length]                  |
+-------------------------------+
```

The returned physical offset begins at `Data`, excluding the type code and length. Runtime version 1 uses an index into the preceding type-name table instead of a primitive `ResourceTypeCode`. The parser maps supported framework primitive types and leaves user-defined serialized records opaque. It never invokes `BinaryFormatter` or a custom deserializer.

## Payload archive

`resources/setups/publish.7z` is a standard 7z stream stored as a ResourceManager `Stream` value. The parser opens a bounded substream over exactly that resource and delegates archive framing to the shared SharpCompress infrastructure. A constant `UnpackingPassword` is passed only to the archive reader and is not included in returned option values, diagnostics, or logs.

The uninstaller template is another managed stream resource. Default extraction includes it only when `IsCreateUninst` is enabled. `-RawResources` exports supported resource streams and byte arrays rather than interpreting `publish.7z` as installed files.
