# The site serves a Cloudflare managed challenge to plain HTTP clients, so the page is
# fetched through the browser. Dependents select installers from the extracted links.
$Page = Invoke-PlaywrightFetch -Uri 'https://www.visionaid.co.uk/visionaid-international---voice-downloads' -Headless -Stealth -SolveCloudflare
$Links = @($Page.Content | Get-EmbeddedLinks)
if ($Links.Count -eq 0) {
  throw 'The VisionAid download page exposed no links; the Cloudflare challenge was probably not solved.'
}

$Global:DumplingsStorage.VisionAidDownloadPage = $Links
