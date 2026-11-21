$Global:DumplingsStorage.CiscoDownloadPage = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://www.webex.com/video-recording.html'
  Read-PlaywrightPageContent -Page $Page
} | Get-EmbeddedLinks
