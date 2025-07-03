$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://www.sonicwall.com/products/remote-access/vpn-clients')

$Global:DumplingsStorage.SonicWallApps = $EdgeDriver.ExecuteScript('return window.__next_f', $null)
