$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://www.ixigua.com/app/')
Start-Sleep -Seconds 10

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//*[@id="App"]/div/main/div/div[1]/div[1]/div[3]/a')).GetAttribute('href')
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsXiguaVideo')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("XiguaVideoSubmitting-$($this.CurrentState.Version)")) {
      $Global:DumplingsStorage["XiguaVideoSubmitting-$($this.CurrentState.Version)"] = $ToSubmit = $true
    }
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()

    if ($ToSubmit) {
      $this.Submit()
    } else {
      $this.Log('Another task is submitting manifests for this package', 'Warning')
    }
  }
}
