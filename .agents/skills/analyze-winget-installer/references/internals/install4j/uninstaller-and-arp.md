# install4j uninstaller and Apps & Features

[Back to install4j internals](overview.md).

## Application identity

The install4j application ID is the normal Windows uninstall-key identity:

```text
Software\Microsoft\Windows\CurrentVersion\Uninstall\<ApplicationId>
```

It is a decimal grouped identifier such as `0804-2950-8354-4050`, not an MSI GUID. Custom registry actions can create other identities, so the application ID is authoritative only when the registration route is present.

## Registration action

`RegisterAddRemoveAction` creates the visible uninstall entry and writes display metadata derived from the application and action properties. Relevant values include display name, version, publisher, install location, icon, links, and the uninstall command.

Generation-3 media can use a built-in registration path associated with the generated uninstaller rather than the later explicit bean representation.

## Registry scope

The registration action writes under HKLM when machine privileges are available and can fall back to HKCU for a user installation. `RequestPrivilegesAction` properties determine whether elevation is attempted, whether failure aborts, and whether the installation directory changes after the scope decision.

An installer that supports both outcomes does not necessarily provide a command line that lets WinGet choose the scope. Static scope capability and manifest-selectable scope are different questions.

## Installed uninstaller

The generated uninstaller is placed under the configured uninstaller directory and filename. It starts the configured uninstaller application, which can run screens and actions just like installation media. The uninstall command normally references this launcher and the installation metadata maintained by install4j.

## Upgrade and maintenance behavior

The application ID connects versions of the same product. Existing-installation checks, overwrite behavior, response values, and update actions decide whether a new setup updates in place, requests removal, or installs alongside an older copy.

`updates.xml` describes available media for install4j's update facilities. It is not the installed ARP database and does not replace the application ID.

## Visibility and custom behavior

An authored installer can omit the registration action, condition it, or add custom registry writes. First-run code can also add associations or state after the installer exits. Static analysis should distinguish the standard ARP route, literal custom writes, conditional effects, and application-owned behavior.
