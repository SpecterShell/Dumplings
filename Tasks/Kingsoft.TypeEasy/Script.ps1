$Object1 = Use-PlaywrightPage -Stealth -Headless {
  param($Page)
  $null = Open-PlaywrightPage -Page $Page -Uri 'https://www.51dzt.com/rubik-ssr/51dzt'
  Invoke-PlaywrightJavaScript -Page $Page -Expression '() => window.__NUXT__.state.application.project_components.find((obj) => obj.name === "dzt-banner").user_props'
}

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
