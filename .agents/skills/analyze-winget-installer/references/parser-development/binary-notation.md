# Binary structure notation

Use protocol-style diagrams for the structures a parser consumes. State whether offsets are absolute, PE-relative, overlay-relative, resource-relative, or record-relative.

```text
Offset  Size  Field
------  ----  --------------------------------
0x00       4  Flags, little-endian uint32
0x04      16  Magic bytes
0x14       4  Decompressed header size
0x18       4  Archive size
```

Use layered maps for nested containers:

```text
PE image
+-- .rsrc: loader metadata
+-- certificate table: updater tag
`-- overlay
    +-- format header
    +-- file catalog
    `-- compressed payload streams
```

Document byte order, signedness, encoding, alignment, padding, repetition, optional and version-dependent fields, pointers, transforms, compression boundaries, and selection rules. Put parser limits and validation invariants beside the affected records. Label proprietary fields `Reserved`, `Unknown`, or `Observed` unless source or stable fixtures prove their semantics.
