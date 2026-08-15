$Global:DumplingsStorage.MimecastDownloadPage = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://mimecastsupport.zendesk.com/hc/en-us/articles/36587212390291-Mimecast-Application-Downloads'
  Read-PlaywrightPageContent -Page $Page
} | ConvertFrom-Html
