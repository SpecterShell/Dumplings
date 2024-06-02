$Object1 = (Invoke-WebRequest -Uri 'https://downloads.surfshark.com/windows/meta/update.xml' | Read-ResponseContent | ConvertFrom-Xml).channels.channel.Where({ $_.name -eq 'stable' }, 'First')[0].releases.release[-1]

# Version
$this.CurrentState.Version = $Object1.version

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version -replace '(?<=^\d+\.\d+\.\d+)\.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.update.url
}

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.description.'#cdata-section' | Format-Text
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
