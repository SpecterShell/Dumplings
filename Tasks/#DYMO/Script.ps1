$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://www.dymo.com/dymo-compatibility-chart.html')
$Global:DumplingsStorage.DYMOApps = $EdgeDriver.PageSource | Get-EmbeddedJson -StartsFrom 'var userObject =' | ConvertFrom-Json -AsHashtable
