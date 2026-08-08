# Scoped browser functions

## Scoped Playwright access

Use Playwright only when ordinary HTTP and structured APIs cannot expose the required source. Keep the lease block short and return strings, URLs, numbers, or dictionaries. A task must not retain a page, locator, context, browser, response, or JavaScript handle after the lease ends.

### `Use-PlaywrightPage`

- **Owner:** PackageModule, `Libraries\Browser\Playwright.psm1`.
- **Schema:** `Use-PlaywrightPage [-ScriptBlock] <scriptblock> [-Browser <Chromium>] [-Channel <string>] [-Headless] [-BlockUrlPattern <string[]>] [-Stealth] [-DisableResources] [-BlockedDomain <string[]>] [-UserAgent <string>] [-Locale <string>] [-TimezoneId <string>] [-ExtraHTTPHeaders <IDictionary>] [-Proxy <uri>] [-ProxyCredential <pscredential>] [-ProxyBypass <string>] [-IgnoreHTTPSErrors] [-BlockWebRTC] [-DisableWebGL] [-DnsOverHttps] [-InitScriptPath <string>] [-ExtraBrowserArgument <string[]>] [-Screenshot]`.
- **Pipeline:** None.
- **Returns:** Script-block output unchanged after releasing the shared browser lease.
- **Use:** Run several dependent browser operations against one leased page.
- **Example:**

```powershell
$InstallerUrl = Use-PlaywrightPage -Headless -Stealth -ScriptBlock { param($Page) $null = Open-PlaywrightPage -Page $Page -Uri $DownloadPage; Read-PlaywrightLocator -Page $Page -Selector 'a.download' -Property Attribute -AttributeName href }
```

- **Notes:** The script block receives `Page`, `Context`, `Browser`, and `Session`. Use the synchronous bridge helpers below instead of awaiting Playwright tasks directly. `-Screenshot` writes final evidence to `Outputs` after success or failure.

### `Invoke-PlaywrightFetch`

- **Owner:** PackageModule, `Libraries\Browser\Playwright.psm1`.
- **Schema:** `Invoke-PlaywrightFetch [-Uri] <uri> [-Headless] [-Stealth] [-DisableResources] [-WaitUntil <string>] [-NetworkIdle] [-WaitSelector <string>] [-WaitSelectorState <string>] [-CaptureXhr <string>] [-PageSetup <scriptblock>] [-PageAction <scriptblock>] [-SolveCloudflare] [-MaximumRetryCount <int>] [-RetryIntervalSeconds <int>] [-Screenshot] [<Playwright session parameters>]`.
- **Pipeline:** None.
- **Returns:** Detached page evidence containing the final URL, status, headers, HTML, body text, challenge state, attempt count, and any selected XHR captures.
- **Use:** Perform one bounded browser fetch without manually managing a page lease.
- **Example:**

```powershell
$Evidence = Invoke-PlaywrightFetch -Uri $DownloadPage -Headless -Stealth -WaitSelector 'a.download' -Screenshot
```

- **Notes:** `-SolveCloudflare` requires `-Stealth` and remains best effort. A delayed or challenged page is not proof that a stable automation source exists.

### `Open-PlaywrightPage`

- **Owner:** PackageModule, `Libraries\Browser\Playwright.psm1`.
- **Schema:** `Open-PlaywrightPage [-Page] <object> [-Uri] <uri> [[-WaitUntil] <Commit|DOMContentLoaded|Load|NetworkIdle>] [[-Referer] <uri>]`.
- **Pipeline:** None.
- **Returns:** The temporary Playwright HTTP response metadata for use inside the active lease.
- **Use:** Navigate the page supplied by `Use-PlaywrightPage`.
- **Example:**

```powershell
$null = Open-PlaywrightPage -Page $Page -Uri $DownloadPage -WaitUntil Load
```

- **Notes:** Do not return the response object from the lease.

### `Read-PlaywrightLocator`

- **Owner:** PackageModule, `Libraries\Browser\Playwright.psm1`.
- **Schema:** `Read-PlaywrightLocator [-Page] <object> [-Selector] <string> [[-Property] <InnerHTML|InnerText|TextContent|Attribute>] [[-AttributeName] <string>] [[-State] <Attached|Visible>] [[-TimeoutMilliseconds] <int>] [-Optional]`.
- **Pipeline:** None.
- **Returns:** One detached string or null for an optional missing locator.
- **Use:** Wait for one element and read its content or attribute without leaking a locator.
- **Example:**

```powershell
$Href = Read-PlaywrightLocator -Page $Page -Selector 'a.download' -Property Attribute -AttributeName href
```

- **Notes:** `-AttributeName` is required for `-Property Attribute`. Prefix XPath selectors with `xpath=`.

### `Read-PlaywrightPageContent`

- **Owner:** PackageModule, `Libraries\Browser\Playwright.psm1`.
- **Schema:** `Read-PlaywrightPageContent [-Page] <object>`.
- **Pipeline:** None.
- **Returns:** The current page HTML as detached text.
- **Use:** Pass the rendered document to PowerHTML after the lease.
- **Example:**

```powershell
$Html = Read-PlaywrightPageContent -Page $Page
```

- **Notes:** Return this string from the scoped block rather than the page object.

### `Invoke-PlaywrightJavaScript`

- **Owner:** PackageModule, `Libraries\Browser\Playwright.psm1`.
- **Schema:** `Invoke-PlaywrightJavaScript [-Page] <object> [-Expression] <string> [[-Argument] <object>] [[-TimeoutMilliseconds] <int>]`.
- **Pipeline:** None.
- **Returns:** A JSON-safe PowerShell value detached from the browser.
- **Use:** Read application state that is exposed only through page JavaScript.
- **Example:**

```powershell
$Data = Invoke-PlaywrightJavaScript -Page $Page -Expression '() => window.__INITIAL_STATE__'
```

- **Notes:** The expression must be a JavaScript function. Arguments and results must be JSON serializable.
