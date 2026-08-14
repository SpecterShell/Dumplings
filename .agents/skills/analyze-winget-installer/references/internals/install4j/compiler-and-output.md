# install4j compiler and output assembly

[Back to install4j internals](overview.md).

## Project loading

The builder reads the `.install4j` project, imported projects, compiler variables, media definitions, source paths, and extension descriptors. It validates object references before collecting files. IDs in the project connect screens, actions, launchers, file sets, and media sets; they are not generally preserved as user-facing product identities.

## Variable expansion

Compiler variables use `${compiler:name}` syntax. The builder resolves them in project properties and generated configuration. Installer variables use a different runtime namespace and survive into the media when their value depends on the target machine.

Build-time expansion also resolves source paths, application version values, generated media names, and platform-specific conditions. An unresolved runtime expression must not be treated as a literal installed path.

The Windows media architecture selects a different native launcher. Controlled install4j 11 output uses configuration `bitness="32"` for x86 and `bitness="64"` for both x64 and ARM64. The PE machine field therefore remains authoritative for distinguishing ARM64 from x64; configuration bitness alone cannot do so.

## File collection

The distribution tree maps source files into installation components. During a build, install4j filters the tree for the selected media set, generates native launchers, collects custom code, and selects a Java runtime when bundling is enabled.

The compiler can download a JDK to compile launchers or create a reduced runtime image. That build JDK is separate from whether the resulting media contains a runtime. A runtime-independent setup can therefore require a JDK during its build while remaining small and requiring Java on the target system.

In generated Windows media, `general@jreVersion` in `i4jparams.conf` records the private runtime version and the startup-file catalog names its archive (`jre.tar.gz` in current media). Runtime-independent media leaves `jreVersion` empty but retains `general@minJavaVersion`. A paired install4j 11 build confirms that these fields distinguish runtime policy without relying on media filenames or file-size heuristics.

## Installer graph serialization

Screens, actions, form components, styles, launchers, and their bean properties are serialized into `i4jparams.conf`. Standard objects are identified by their runtime classes. Custom classes and extension metadata are packaged in JARs.

The builder emits the application ID and application version into configuration data. Some generated media also writes a launcher-generation marker into parameter `2000`; controlled install4j 11 application media shows that this marker is optional even when the modern launcher record is complete.

## Native media assembly

For Windows setup EXEs, the builder selects a native launcher stub, writes PE resources, serializes launcher parameter maps, appends transformed startup files, then writes the content catalog and payload streams.

```text
native stub
  -> PE resources and version information
  -> launcher overlay and startup records
  -> ContentCollector descriptors
  -> compressed application/runtime archive
  -> optional signature
```

Generation 3 uses an inline ZIP. Generation 4 uses a split `.000` LZMA stream. Modern generations normally use `0.dat`, which expands to a ZIP archive.

## Build outputs

A build can emit setup executables, archives, checksums, and `updates.xml`. Media names and update URLs belong to the media-set configuration, not the application ID. The same project can emit several files with the same product identity but different architectures or runtime policies.

Signing occurs after the executable content is assembled. PE certificate data must therefore be excluded when locating the physical overlay boundary.
