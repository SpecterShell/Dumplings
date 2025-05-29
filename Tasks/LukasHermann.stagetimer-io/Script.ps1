$Object1 = Invoke-RestMethod -Uri 'https://europe-west1-stagetimer-prod.cloudfunctions.net/getOfflineVersionManifest'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl1st -Uri $Object1.files.Where({ $_.plattform -eq 'windows' -and $_.architecture -eq 'x64' }, 'First')[0].downloadUrl -Method Get
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
