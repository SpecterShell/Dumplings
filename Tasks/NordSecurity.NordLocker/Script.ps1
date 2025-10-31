$Object1 = (Invoke-WebRequest -Uri 'https://downloads.nordcdn.com/apps/windows/meta/NordLockerEvolution/latest/update_x64.xml' | Read-ResponseContent | ConvertFrom-Xml).channels.channel.Where({ $_.name -eq 'default' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.releases.release.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.releases.release.update.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.releases.release.description.'#cdata-section' | ConvertFrom-Json | ConvertTo-UnorderedList | Format-Text
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
  }
  'Updated' {
    $this.Submit()
  }
}
