$Object1 = Invoke-RestMethod -Uri 'https://pkgs.dev.azure.com/NC-FLOW/c34daccf-1296-47b5-8591-66ab5e0dc7cb/_packaging/bd2d042a-4006-4a45-99a1-7d4f37ab6a56/nuget/v3/registrations2-semver2/novacura.flow.installer/index.json'

# Version
$this.CurrentState.Version = $Object1.items.items[0].catalogEntry.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.items.items[0].packageContent
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.items.items[0].catalogEntry.published.ToUniversalTime()
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
