$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://lmstudio.ai/')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $EdgeDriver.FindElement([OpenQA.Selenium.By]::XPath('//a[contains(@href, ".exe")]')).GetAttribute('href')
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Global:DumplingsStorage.Contains('LMStudio') -and $Global:DumplingsStorage.LMStudio.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.LMStudio[$this.CurrentState.Version].ReleaseNotes
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
    $this.Submit()
  }
}
