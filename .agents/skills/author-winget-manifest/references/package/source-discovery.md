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
- Treat popular packages with many fake results as high risk. Do not use search-result download links without official cross-reference proof.

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

### Challenge-protected sites

Turnstile and other CAPTCHA or bot-protection systems may reject browser DevTools automation, browser MCPs, and browser CLIs even when the same page works in a manually opened browser. These tools often launch browsers with automation flags or enable protocol features that expose detectable signals, such as `navigator.webdriver`. Detection depends on the browser's launch and instrumentation. Cloudflare documents [automated-browser blocking](https://developers.cloudflare.com/turnstile/troubleshooting/testing/) and [unsupported production challenge environments](https://developers.cloudflare.com/cloudflare-challenges/reference/supported-browsers/).

For [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp), prefer connecting to an existing, locally running Chrome instance with `--autoConnect`. This requires Chrome 144 or later. Start Chrome manually, enable remote debugging at `chrome://inspect/#remote-debugging`, and approve its connection prompt. The server discovers the browser through the user data directory for `--channel`, which defaults to `stable`. See the [connection guide](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/advanced-usage.md#automatically-connecting-to-a-running-chrome-instance) and [configuration reference](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/configuration.md).

Configure the MCP client with this server command:

```powershell
npx -y chrome-devtools-mcp@latest --autoConnect
```

For the [Chrome DevTools CLI](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/cli.md), select the same connection mode at startup:

```powershell
chrome-devtools start --autoConnect
```

Starting a fresh Chrome instance through the MCP or CLI can still expose automation markers. Attaching to an existing instance avoids that launch path but does not guarantee challenge acceptance. Obtain the user's approval before attaching to a personal profile, because the connection exposes its open windows and browser state.

[Patchright](https://github.com/Kaliiiiiiiiii-Vinyzu/patchright) patches Chromium automation flags and some Chrome DevTools Protocol signals used for detection. Community interfaces include [patchright-mcp-lite](https://github.com/dylangroos/patchright-mcp-lite) for MCP and [patchright-cli](https://github.com/AhaiMk01/patchright-cli) for CLI use. Consider them when ordinary browser automation is blocked, subject to their current setup requirements. For Dumplings scripts, prefer the existing [scoped browser helpers](../../../use-dumplings-functions/references/browser.md) before adding another runtime.

Neither connection mode nor Patchright guarantees passing a CAPTCHA. If a challenge persists, ask the user to open the official page manually or use another public first-party source. Record the blocked URL and a screenshot, and keep cookies and challenge tokens out of saved evidence.

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
