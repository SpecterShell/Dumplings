# QSetup binary format

## Container layers

```text
single-file setup.exe
+-- native PE image
`-- overlay
    +-- generation preamble
    +-- optional split descriptor
    +-- repeated compressed records
    |   +-- decoded record header
    |   `-- payload bytes
    +-- generation footer
    +-- optional zero alignment
    `-- optional WIN_CERTIFICATE records

split companion
+-- generation preamble at offset zero
+-- split descriptor
+-- compressed records
`-- footer

spanned media
`-- setup.exe || .001 || .002 || ... as one logical byte stream
```

All integer fields described here are little-endian unless stated otherwise. Offsets in footers are absolute within the logical media stream. Records are physically adjacent and advance by their declared compressed length.

## Preamble routes

QSetup 1 and 2 start with the first record.

```text
Base       Offset  Size  Field
---------  ------  ----  -----------------------------------------
[overlay]  0x00    4     First CompressedLength:u32
[overlay]  0x04    N     First zlib member
```

QSetup 3 through 5 add a double-pipe preamble.

```text
Base       Offset  Size  Field
---------  ------  ----  -----------------------------------------
[overlay]  0x00    4     FormatVersion:u32
[overlay]  0x04    2     ASCII "||"
[overlay]  0x06    4     PreambleLength:u32
[overlay]  0x0A    N     UTF-8 pipe-delimited preamble
```

QSetup 7 and later add an explicit compression-format byte.

```text
Base       Offset  Size  Field
---------  ------  ----  -----------------------------------------
[overlay]  0x00    4     FormatVersion:u32
[overlay]  0x04    1     CompressionFormat:u8
[overlay]  0x05    4     PreambleLength:u32
[overlay]  0x09    N     UTF-8 pipe-delimited preamble
```

The UTF-8 preamble begins and ends with a pipe and contains an executable-name field. Its remaining fields are retained as evidence because labels and uses changed across releases. Every verified payload record still uses zlib; an unfamiliar format byte does not authorize another decoder.

## Split descriptor

```text
Base          Offset  Size  Field
------------  ------  ----  --------------------------------------------------------------
[descriptor]  0x00    4     DescriptorLength:u32
[descriptor]  0x04    N     |SourceDirectory|CompanionName|Mode|Secret|DeclaredLength?|
```

The kernel descriptor has the optional declared companion length; the companion omits it because the stream length is already known. `CompanionName` must be a leaf name, decimal fields must parse exactly, and the observed secret is 16 through 128 lowercase ASCII letters. Kernel and companion preambles, secret, name, and declared length must agree.

## Record framing

```text
Base      Offset  Size  Field
--------  ------  ----  ------------------------------------------
[record]  0x00    4     CompressedLength:u32
[record]  0x04    N     complete RFC 1950 zlib member
[decoded] 0x00    M     |Name[*]?|Stamp|, ASCII, maximum 4096 bytes
[decoded] M       1     BodyMarker = 0x00
[decoded] M+1     ...   payload bytes
```

`*` marks a required physical record. `Name` cannot contain a pipe or `*`; `Stamp` is decimal text. The NUL is framing and is consumed before extraction. Enumeration inflates only the bounded header. `Setup.txt`, selective analysis, and explicit extraction read payload bytes under their own output limits.

## Terminal routes

QSetup 1 and 2 use a compact footer.

```text
Base      Offset  Size  Field
--------  ------  ----  ------------------------------------------
[footer]  0x00    4     RecordCount:u32
[footer]  0x04    4     OverlayOffset:u32
[footer]  0x08    4     Magic:u32 = 0x4A3B2C1D
```

QSetup 3 through 11 use the legacy 74-byte footer.

```text
Base      Offset  Size  Field
--------  ------  ----  ------------------------------------------
[footer]  0x00    4     FooterVersion:u32
[footer]  0x04    4     OverlayOffset:u32
[footer]  0x08    4     RecordCount:u32
[footer]  0x0C    4     Magic:u32 = 0x4A3B2C1D
[footer]  0x10    4     observed generation field, not 1234
[footer]  0x14    50    observed or reserved fields
[footer]  0x46    4     FooterLength:u32 = 74
```

QSetup 12 uses the same length with a marker-bearing profile.

```text
Base      Offset  Size  Field
--------  ------  ----  ------------------------------------------
[footer]  0x00    4     FooterVersion:u32
[footer]  0x04    4     OverlayOffset:u32
[footer]  0x08    4     RecordCount:u32
[footer]  0x0C    4     Magic:u32 = 0x4A3B2C1D
[footer]  0x10    4     Marker:u32 = 1234
[footer]  0x14    50    version-dependent fields
[footer]  0x46    4     FooterLength:u32 = 74
```

Footer offset, record count, magic, self-length, parsed endpoint, zero alignment, and complete certificate trailer must agree. QSetup 7.5 and 8.1 can carry valid certificate records that the PE security directory does not declare, so the terminal reader validates the envelope at the actual record boundary.

Each `WIN_CERTIFICATE` record contains `dwLength:u32`, `wRevision:u16`, `wCertificateType:u16`, and certificate bytes, rounded to eight bytes. Accepted revisions are `0x0100` and `0x0200`; the accepted type is PKCS signed data (`2`). A footerless stream is accepted only when records end at exact physical EOF.
