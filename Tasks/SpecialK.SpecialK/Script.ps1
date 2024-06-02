$Object1 = Invoke-RestMethod -Uri 'https://sk-data.special-k.info/repository.json'

# Version
$this.CurrentState.Version = $Object1.Main.Versions[0].Name

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Main.Versions[0].Installer
}

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.Main.Versions[0].ReleaseNotes | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
