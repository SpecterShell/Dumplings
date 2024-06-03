$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://www.51dzt.com/rubik-ssr/51dzt')

$Object1 = $EdgeDriver.ExecuteScript('return window.__NUXT__.state.application.project_components.filter(obj => obj.name === "dzt-banner")[0].user_props', $null)

# Version
$this.CurrentState.Version = [regex]::Match($Object1.downloadVersion, '（([\d\.]+)）').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = ($Object1.download | ConvertFrom-Json).event.Where({ $_.type -eq 'openLink' }, 'First')[0].params.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object1.downloadVersion, '(\d{4}\.\d{1,2}\.\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
