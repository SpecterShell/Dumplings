# The site serves a Cloudflare managed challenge to plain HTTP clients, so the page is
# fetched through the browser. Dependents select installers from the extracted links.
$Global:DumplingsStorage.DMTDownloadPageUrl = 'https://www.dmt.dk/software-downloads.html'

$Page = Invoke-PlaywrightFetch -Uri $Global:DumplingsStorage.DMTDownloadPageUrl -Headless -Stealth -SolveCloudflare
$Links = $Page.Content | Get-EmbeddedLinks
if (-not $Links) {
  throw 'The DMT download page exposed no links; the Cloudflare challenge was probably not solved.'
}

$Global:DumplingsStorage.DMTDownloadPage = $Links
