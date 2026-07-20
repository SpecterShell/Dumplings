$Global:DumplingsStorage.DYMOApps = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://www.dymo.com/dymo-compatibility-chart.html'
  Read-PlaywrightPageContent -Page $Page
} | Get-EmbeddedJson -StartsFrom 'var userObject =' | ConvertFrom-Json -AsHashtable
