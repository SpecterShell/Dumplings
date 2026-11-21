$Object1 = Invoke-RestMethod -Uri 'https://aux-zlrkq6pata-ew.a.run.app/desktop-app/files'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl1st -Uri $Object1.Where({ $_.plattform -eq 'windows' -and $_.architecture -eq 'x64' }, 'First')[0].downloadUrl -Method Get
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value

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
