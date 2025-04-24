$Object1 = Invoke-RestMethod -Uri 'https://pkgs.dev.azure.com/NC-FLOW/c34daccf-1296-47b5-8591-66ab5e0dc7cb/_packaging/flow-6-production/nuget/v3/index.json'
$Object2 = Invoke-RestMethod -Uri (Join-Uri $Object1.resources.Where({ $_.'@type' -eq 'RegistrationsBaseUrl/Versioned' }, 'First').'@id' 'novacura.flow.studio/index.json')

# Version
$this.CurrentState.Version = $Object2.items.items[0].catalogEntry.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.items.items[0].packageContent
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.items.items[0].catalogEntry.published.ToUniversalTime()
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
