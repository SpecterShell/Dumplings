# install4j architecture

[Back to install4j internals](overview.md).

## Authoring model

An install4j project is XML. Its major object groups are the application, launchers, installer GUI, media sets, files, runtime selection, compiler variables, and optional update configuration. A project can emit several media files with different platforms, architectures, runtime policies, and names.

```text
project
+-- application identity and Java requirements
+-- distribution tree and source files
+-- launchers and services
+-- installer and uninstaller applications
|   +-- screens and form components
|   `-- ordered actions and action groups
+-- compiler variables and custom code
`-- media sets
    +-- Windows x86/x64/ARM64 setup
    +-- bundled-runtime or runtime-independent media
    `-- archive, MSI, or other supported output
```

The authoring project is richer than the shipped setup configuration. Build logic resolves source-only paths, excludes unused objects, and converts bean properties into the runtime representation.

## Native launcher layer

The Windows setup begins as a native PE executable. It owns early command-line handling, working-directory setup, integrity checks, Java discovery, and the transition into the Java runtime. This layer must work before any installer screen or Java action can execute.

The PE architecture is the launcher architecture. A media set may carry a Java runtime and application files with their own architecture requirements. The installed launchers generated for the application are separate native programs.

## Java installer layer

`i4jruntime.jar` implements the installer framework. `i4jparams.conf` describes the selected installer application and its object graph. The runtime creates screen, form-component, and action objects, applies serialized properties, and walks the configured sequence for GUI, console, or unattended mode.

Custom code can enter through project classes, extension JARs, script expressions, event listeners, and custom installer applications. These calls are normal Java execution and are not constrained to declarative effects.

## Content layer

The launcher needs a small startup set immediately. Larger application files are catalogued separately and are commonly compressed as a ZIP carried by an LZMA stream.

```text
startup set
+-- runtime/configuration needed to enter Java
`-- small resources needed before content extraction

content set
+-- application files
+-- generated native launchers
+-- optional runtime image
+-- user and extension JARs
`-- installed uninstaller resources
```

Some media keeps application data external or downloads it later. The local configuration remains useful even when the complete installed tree is absent.

## Maintenance layer

The installed uninstaller is another install4j launcher. It reads installation metadata and runs the configured uninstaller application. Update and response files can alter the path through the same installer object graph.

ARP registration is an authored runtime action rather than an unavoidable PE launcher feature. The application ID normally names the uninstall key, while the registration action controls displayed values and visibility.

## Trust boundaries

Static analysis crosses four trust boundaries:

- Native launcher records can be parsed and range-checked.
- Configuration XML can be decoded as data.
- Standard action classes can be interpreted only to the extent their serialized properties define behavior.
- Custom Java/native code and target-machine state remain opaque without a separate code analysis or VM observation.
