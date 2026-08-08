# Release evidence

## Release Notes Discovery

Git-hosted applications may publish installers through repository releases even when the application itself is closed source. Treat the official repository and its release pages as valid first-party sources; `InTheLoop.LoopEmail` is an example of this distribution model.

For GitHub, GitLab, Gitea, Codeberg, Bitbucket, Gitee, GitCode, and similar platforms, inspect release-note sources in this order:

1. The body of the exact release that provides the selected desktop installer.
2. A version entry in a repository-root release history such as `CHANGELOG.md`, `RELEASES.md`, or `CHANGES.md`, including case and naming variants.
3. The desktop application's official homepage, documentation, support site, or dedicated release-history page.

A release body is not valid release notes merely because it exists. Reject an empty body, a body containing only the version/title, generated assets or download links, checksums, or other text that does not describe product changes. For example, the [ImageMagick 7.1.2-27 release](https://github.com/ImageMagick/ImageMagick/releases/tag/7.1.2-27) contains no substantive change list, so use the repository release-history files or official site instead.

For applications not released through a Git platform, search the official site footer, download page, support pages, and documentation. Confirm that the selected page describes the Windows desktop application. Do not use platform-service updates, server-only changes, web-product updates, or mobile-app release notes for a desktop manifest.

Record two sources separately:

- The raw HTML or Markdown source used to build `ReleaseNotes`.
- The human-readable official page used as `ReleaseNotesUrl`, preferably a version-specific release page or changelog anchor rather than a raw-content URL.

## Release Date Evidence

Capture `ReleaseDate` while resolving the version and installer URL:

1. For a GitHub source, use the publication date of the exact release whose assets are selected. Do not use the repository commit date or a different channel's release.
2. Otherwise use the date on an official version-specific release-notes or release-history page.
3. If neither exists, use the `Last-Modified` header returned for the installer URL.

Record the URL and evidence type with the date so later automation can reproduce it. Treat a changed `Last-Modified` value on a stable mutable URL as update-detection evidence, but do not override a more authoritative release publication date.
