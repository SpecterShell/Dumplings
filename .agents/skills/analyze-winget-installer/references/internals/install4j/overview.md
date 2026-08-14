# install4j internals

This directory explains how install4j turns a project, application files, Java launchers, installer actions, and an optional Java runtime into Windows media. It follows the producer and runtime rather than the Dumplings command surface.

Use the [install4j package workflow](../../families/install4j/workflow.md) when the immediate goal is a WinGet manifest. Dumplings-specific format routing is kept in [parser implementation notes](parser-implementation.md), and current support is recorded in [coverage and remaining work](coverage.md).

## Reading path

1. [Architecture](architecture.md) introduces the project model, compiler, launchers, installer runtime, payload catalog, and generated uninstaller.
2. [Compiler and output assembly](compiler-and-output.md) follows a project through variable expansion, launcher generation, runtime selection, compression, and media output.
3. [Binary format](binary-format.md) documents the PE overlay, parameter maps, startup files, ContentCollector table, transforms, and nested archives.
4. [Metadata model](metadata-model.md) describes `i4jparams.conf`, application identity, media settings, screens, actions, launchers, and associations.
5. [Setup runtime](setup-runtime.md) follows startup, Java discovery, unattended modes, privilege changes, actions, rollback, and exit behavior.
6. [Variables, expressions, and custom code](scripting-and-expressions.md) separates compiler variables, installer variables, expressions, Java callbacks, and custom installer applications.
7. [Uninstaller and ARP](uninstaller-and-arp.md) covers application IDs, `RegisterAddRemoveAction`, scope, maintenance, updates, and removal.
8. [Format history](format-history.md) records the recoverable Windows media generations from install4j 3 through 13.
9. [Parser implementation notes](parser-implementation.md) maps those structures to bounded static analysis.
10. [Coverage and remaining work](coverage.md) contains implementation parity, known defects, unsupported behavior, and the fixture matrix.

## One media file contains several programs

An install4j Windows setup is a native launcher that starts a Java installer application. The setup executable also carries configuration and application payloads needed before Java code can run.

```text
Windows setup.exe
+-- native PE launcher
|   +-- platform startup and Java discovery
|   +-- error messages and launcher resources
|   `-- overlay reader
`-- install4j overlay
    +-- launcher parameter maps
    +-- XOR-transformed startup files
    |   +-- i4jruntime.jar
    |   +-- i4jparams.conf
    |   `-- icons and installer resources
    +-- ContentCollector file catalog
    +-- compressed application archive
    `-- optional bundled Java runtime
```

The native launcher is enough to display startup failures and locate a Java runtime. Installer screens and actions are Java objects described by `i4jparams.conf` and implemented by `i4jruntime.jar`, user code, or extension JARs.

## Build-time and run-time models

```text
Build time
+-- parse .install4j project XML
+-- resolve compiler variables and source paths
+-- collect application files and runtime components
+-- serialize installer applications, screens, actions, and launchers
+-- generate native platform launchers
`-- compress and sign selected media files

Native startup
+-- parse launcher parameter maps and startup-file table
+-- locate or unpack a suitable Java runtime
+-- read i4jparams.conf and prepare the class path
`-- start the selected installer application

Installer runtime
+-- select GUI, console, or unattended mode
+-- evaluate screens, actions, conditions, and response values
+-- request privileges when configured
+-- install files and create system state
+-- register maintenance and uninstall information
`-- commit, roll back, or return an exit code

First application run
`-- outside install4j; the application may create additional state
```

Compiler variables are normally replaced before the media is written. Runtime installer variables and custom Java code can still change paths, conditions, registry values, and control flow on the target machine.

## Identity domains

Several independent values can look like an install4j version or product ID:

| Identity | Meaning |
| --- | --- |
| Builder release | The install4j release used to compile the project, when `i4jparams.conf` records it. |
| Launcher generation | The serialized native-launcher and payload ABI selected by the catalog. |
| Launcher marker | Optional parameter-map value used by some vendor and builder media to identify a generation. |
| Application ID | Stable install4j product identity, normally written as the uninstall-key name. |
| Media set ID | Identity of one build target inside the project; it is not the ARP ProductCode. |
| PE product version | Version resource of the generated launcher or packaged application. It is not reliable builder-generation evidence. |
| Application version | Publisher-controlled version displayed by the installer and ARP entry. |

The Windows and Multi-Platform commercial editions use the same builder and media implementation. A license controls which targets can be built, so shipped Windows media cannot establish the purchased edition.

## Static and dynamic evidence

The overlay can prove framing, startup-file names, embedded configuration, payload boundaries, and checksums. Configuration XML can prove literal product metadata and the presence of authored actions. It cannot execute arbitrary Java expressions, extension code, downloaded payloads, or target-state checks.

A literal `RegisterAddRemoveAction` is static ARP evidence. Its actual registry root can still depend on privilege acquisition. A custom action that writes an additional uninstall key is runtime evidence until its code is analyzed or the installer is validated in a VM.

## Important shipped artifacts

| Artifact | Role |
| --- | --- |
| `*.install4j` | Authoring project XML consumed by the builder. |
| `i4jparams.conf` | Serialized application, launcher, installer, screen, action, variable, and media configuration. |
| `i4jruntime.jar` | Runtime implementation for installer applications and standard actions. |
| `user.jar` and extension JARs | Compiled project code and custom extensions. |
| `0.dat` or `*.000` | Compressed application-content archive in later media generations. |
| `content.zip` | Inline generation-3 application archive. |
| `uninstall.exe` | Generated maintenance/uninstall launcher installed with the product. |
| `updates.xml` | Optional update descriptor emitted beside media files. |

## Source references

- [install4j documentation](https://www.ej-technologies.com/resources/install4j/help/doc/)
- [install4j media files](https://www.ej-technologies.com/resources/install4j/help/doc/concepts/mediaFiles.html)
- [install4j launchers](https://www.ej-technologies.com/resources/install4j/help/doc/concepts/launchers.html)
- [install4j installer applications](https://www.ej-technologies.com/resources/install4j/help/doc/concepts/installerApplications.html)
- [install4j installer options](https://www.ej-technologies.com/resources/install4j/help/doc/installers/options.html)
- [install4j change log](https://www.ej-technologies.com/install4j/changelog)
- [install4j editions](https://www.ej-technologies.com/install4j/editions)
