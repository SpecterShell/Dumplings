$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://www.sonicwall.com/products/remote-access/vpn-clients')
$null = $EdgeDriver.ExecuteScript('self.__next_f = [];', $null)
$null = $EdgeDriver.ExecuteScript($EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//script[contains(., "ConnectTunnel")]')).GetAttribute('textContent'), $null)
$null = $EdgeDriver.ExecuteScript($EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//script[contains(., "GVCSetup")]')).GetAttribute('textContent'), $null)
$null = $EdgeDriver.ExecuteScript($EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//script[contains(., "NetExtender for Windows")]')).GetAttribute('textContent'), $null)
$Global:DumplingsStorage.SonicWallApps = $EdgeDriver.ExecuteScript('return self.__next_f', $null)
