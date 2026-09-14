# MicaSetup architecture

## Producer pipeline

MicaSetup distributes source templates rather than a data-only setup compiler. MakeMica updates generated C# option assignments, copies application output into `publish.7z`, adds setup resources, compiles the WPF host, and rewrites assembly identity for the packaged application. The resulting EXE contains both the generic runtime and package-specific managed code.

```text
application publish directory
        |
        +-- archive as publish.7z
        |
MicaSetup source template
        +-- generated Pack/Option assignments
        +-- optional developer edits and handlers
        +-- language, license, certificate, and image resources
        |
        `-- C# compiler -> managed WPF setup.exe
```

This design gives package authors more freedom than formats with a closed declarative project model. The parser can interpret source-backed generated patterns, but it cannot assume that every method in the setup came from the upstream template.

## Runtime layers

The outer PE supplies the CLR metadata, generated configuration, WPF UI, elevation host, and managed resources. The `publish.7z` resource supplies application files. The `uninst.exe` resource supplies the uninstaller template when uninstaller creation is enabled. Application binaries may add first-run associations or services that are absent from the setup's generated option model.

```text
outer setup process
+-- command-line tokenization
+-- optional single-instance and temporary-path fork
+-- optional elevated relaunch
+-- WPF page flow and license presentation
+-- 7z extraction
+-- built-in shortcuts, ARP, PATH, firewall, certificate, and ACL effects
+-- optional generated uninstaller
`-- optional application launch

installed application
+-- files from publish.7z
+-- generated Uninst.exe or uninst.exe
+-- optional Uninst.dat
`-- possible first-run effects owned by the application
```

## Identity domains

Assembly title, product, company, and version identify the packaged application because MakeMica rewrites them. Pack or Option values identify the configured setup behavior. Payload PE metadata identifies installed binaries. The ARP key derives from `KeyName` only when the built-in elevated registry path executes. These identities often agree, but they are not interchangeable evidence.

| Identity | Source | Use |
| --- | --- | --- |
| Application identity | assembly attributes and Pack/Option fields | display metadata and consistency checks |
| Setup configuration identity | `AppName`, `DisplayName`, `DisplayVersion`, `Publisher`, `KeyName` | built-in runtime behavior |
| Payload identity | selected main executable and sidecars | architecture and dependency evidence |
| ARP identity | elevated built-in registry gate or literal custom registry writes | ProductCode and Apps & Features matching |

## Trust boundaries

The installer assembly is untrusted input. The parser reads metadata through `PEReader` and `MetadataReader`; it never loads the target assembly, invokes its methods, or constructs its custom resource types. CIL evaluation is symbolic and bounded. Resource values are accepted only when their type and physical range are supported. The payload archive is opened through a bounded stream, and extraction applies the shared path, count, size, and collision controls.

Custom C# is an explicit boundary. A method call can read the registry, network, clock, architecture, or user interface and then assign an option. Unless the evaluator implements that exact pure operation and all operands are known, the result remains unresolved. The analyst should inspect available source or validate the concrete effect in a VM.
