# agtek.com serves a Cloudflare managed challenge to plain HTTP clients, so the page is
# fetched through the browser. Dependents query the download table through SelectSingleNode.
$Page = Invoke-PlaywrightFetch -Uri 'https://agtek.com/services-support/product-downloads/' -Headless -Stealth -SolveCloudflare

$Global:DumplingsStorage.AGTEKDownloadPage = $Page.Content | ConvertFrom-Html
if (-not $Global:DumplingsStorage.AGTEKDownloadPage.SelectSingleNode('//td[@class="td-filename"]')) {
  throw 'The AGTEK download table is missing; the Cloudflare challenge was probably not solved.'
}

$Global:DumplingsStorage.AGTEKAppInstallerSource = Invoke-RestMethod -Uri 'https://agtek.s3.amazonaws.com/Agtek/EUkxrlekp0K4'
