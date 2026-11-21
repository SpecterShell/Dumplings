$Object1 = (Invoke-WebRequest -Uri 'https://sk-data.special-k.info/repository.json').Content | ConvertFrom-Json -AsHashtable

# Version
$this.CurrentState.Version = $Object1.Main.Versions[0].Name

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Main.Versions[0].Installer
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.Main.Versions[0].ReleaseNotes | Format-Text
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
