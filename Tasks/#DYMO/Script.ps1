$Global:DumplingsStorage.DYMOApps = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://www.dymo.com/dymo-compatibility-chart.html'
  Read-PlaywrightLocator -Page $Page -Selector 'xpath=//script[@data-dymo-v2-data and @type="application/json"]'
} | ConvertFrom-Json -AsHashtable
