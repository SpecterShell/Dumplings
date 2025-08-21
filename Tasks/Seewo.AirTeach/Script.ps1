$Object1 = $Global:DumplingsStorage.SeewoApps['AirTeach']

# Version
$this.CurrentState.Version = [regex]::Match($Object1.softInfos.Where({ $_.useSystem -eq 1 }, 'First')[0].softVersion, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.softInfos.Where({ $_.useSystem -eq 1 }, 'First')[0].downloadUrl
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
