$Global:DumplingsStorage.RevopointDownloadPage = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://www.revopoint3d.com/pages/support-download'
  Read-PlaywrightPageContent -Page $Page
} | ConvertFrom-Html
