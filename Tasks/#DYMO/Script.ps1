$Global:DumplingsStorage.DYMOApps = Use-EdgeDriver {
  param($EdgeDriver)
  $EdgeDriver.Navigate().GoToUrl('https://www.dymo.com/dymo-compatibility-chart.html')
  $EdgeDriver.PageSource
} | Get-EmbeddedJson -StartsFrom 'var userObject =' | ConvertFrom-Json -AsHashtable
