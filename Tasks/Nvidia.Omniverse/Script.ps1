$Prefix = 'https://install.launcher.omniverse.nvidia.com/installers/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri "https://docs.omniverse.nvidia.com/launcher/latest/release-notes/$($this.CurrentState.Version.Replace('.', '_')).html" | ConvertFrom-Html

      # Remove links
      $Object2.SelectNodes('//a[@class="headerlink"]').ForEach({ $_.Remove() })

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes('//section[@id="id1"]/following-sibling::node()') | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
