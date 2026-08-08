# Official source discovery

## Source Classification

Classify the package source first:

- `Homepage`: Proprietary or publisher-hosted applications where installers are linked from the product page, download page, or support page.
- `GitHub`: Open-source or publisher-hosted projects where installers are release assets in an official GitHub repository.
- `Other official forge`: Sourcehut, GitLab, Codeberg, vendor CDN release pages, or other first-party release locations.

If a homepage links to GitHub releases, switch to the GitHub path. If a GitHub repository links back to a homepage, verify both are mutually connected.

## Homepage And Vendor Sites

Start from the package homepage when known. If unknown, use search cautiously:

- Prefer official publisher domains, documentation pages, support pages, store pages, and linked social/profile pages.
- Cross-reference at least two independent search results or official pages before trusting a domain.
- Verify that official pages navigate to each other: homepage to download page, GitHub to homepage, documentation to publisher, or support page to product.
- Check whether the product was acquired, merged, or rebranded. Distinguish acquisition from product-identity replacement: if the acquired company and brand remain the product's developer identity, retain them for a new package identifier and `Author`, while using the parent company's current URLs where appropriate.
- Reject third-party download sites, including download aggregators, mirrors, repackagers, software-informer sites, Softonic-style sites, MajorGeeks-style sites, and SEO spam pages.
- Treat popular packages with many fake results as high risk; do not use search-result download links without official cross-reference proof.

Common homepage download patterns:

- The installer link is directly on the homepage or product download page.
- The installer link is fetched dynamically by page JavaScript through an API request.
- The installer link is embedded inside bundled JavaScript files.
- The page starts a download automatically after a countdown.
- The installer link is on a support, release notes, or archived download page rather than the marketing homepage.
- The download requires submitting a promotion form.

## Dynamic Download Pages

If the link is not visible in static HTML:

- Inspect the HTML source for installer URLs, API endpoints, release JSON, and JavaScript bundle names.
- Use browser DevTools, network logs, or an available browser MCP to capture `fetch`/XHR requests and redirect chains.
- Search JavaScript bundles for file extensions, version strings, CDN hostnames, and API route names.
- For automatic countdown downloads, inspect the countdown script and network activity instead of waiting blindly.
- Record the original page URL and the final installer URL.
- Refresh the page and repeat the capture. If installer URLs, API responses, or redirect targets change between refreshes, treat the URL as dynamic until proven stable.

If no DevTools MCP is available, use the in-app browser, command-line HTTP requests, and static source inspection. Do not claim DevTools evidence unless it was actually captured.

## Forms

It is acceptable to submit non-sensitive promotional forms with placeholder information, for example:

- Name: `Thank You`
- Email: `no@thank.you`
- Country: any plausible value
- Phone: any plausible dummy value

Continue only if the site returns the installer link directly in the browser response or page. Stop and warn immediately if the site says the download link will be sent by email or requires access to an inbox.

Do not create accounts, bypass paywalls, use personal data, or use private credentials unless the user explicitly provides an approved workflow.

## GitHub Sources

Use the latest release assets from the official repository:

- Prefer the latest non-prerelease release for stable packages.
- Use prerelease releases only for packages that are explicitly preview, beta, nightly, canary, or otherwise channel-specific.
- If release assets contain multiple product families, split them into separate packages when the installed products are distinct. Examples include desktop vs CLI packages or multiple build variants.
- Report repository legitimacy signals: star count, commit count, open issue count, open pull request count, archived status, latest release tag, and whether releases are still expected.
- Check whether the repository is official by verifying links from the project website, organization profile, README, package metadata, or existing manifests.

Flag suspicious GitHub sources:

- Repo has little activity and no official cross-links but claims a well-known product.
- Official website points elsewhere or does not mention the repo.
- Release assets are repackaged installers from another vendor.
- The repo is archived and automation would not expect future releases.

Known anti-pattern:

- `AppWork.JDownloader` issue `microsoft/winget-pkgs#354250` reported a manifest update that changed the installer source from the official JDownloader domain to a personal GitHub mirror and used a version number not published by the vendor. Treat this as a blocking pattern: an existing package must not switch from the publisher domain to an unaffiliated GitHub account unless the publisher explicitly links that repository as official.
- When a package has no official GitHub presence, do not use community mirrors even if their release assets appear to install correctly and have stable hashes.
- For existing packages, compare the proposed source against previous manifests. A domain change from the official vendor source to GitHub, a new CDN, or a personal account requires explicit publisher cross-link evidence before continuing.
