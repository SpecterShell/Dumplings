# Release date evidence

Capture the installer manifest's `ReleaseDate` while resolving the version and installer URL:

1. For a GitHub source, use the publication date of the exact release whose assets are selected. Do not use a different channel's release.
2. Otherwise use the date on an official version-specific release-notes or release-history page.
3. If neither exists, use the `Last-Modified` header returned for the installer URL.

Record the URL and evidence type with the date so later automation can reproduce it. Do not substitute a page update date, repository commit date, or unrelated asset timestamp. Treat a changed `Last-Modified` value on a stable mutable URL as update-detection evidence, but do not override a more authoritative release publication date.

Follow [Release notes](../locale/content-and-resources.md#release-notes) for the locale manifest's release text and source URL.
