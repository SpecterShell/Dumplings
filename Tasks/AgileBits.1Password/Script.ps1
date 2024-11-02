$Object1 = Invoke-RestMethod -Uri "https://app-updates.agilebits.com/check/2/10.0.22000/x86_64/OPW8/en/$($this.LastState.Contains('RawVersion') ? $this.LastState.RawVersion: '81026039')/A1/N"

if ($Object1.available -eq '0') {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = "https://downloads.1password.com/win/1PasswordSetup-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msi'
  InstallerUrl  = "https://downloads.1password.com/win/1PasswordSetup-$($this.CurrentState.Version).msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'exe'
  InstallerUrl  = "https://downloads.1password.com/win/arm64/1PasswordSetup-$($this.CurrentState.Version)-arm64.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RawVersion
    $RawVersion = $InstallerFile | Read-FileVersionRawFromExe
    $this.CurrentState.RawVersion = "$($RawVersion.Major)$($RawVersion.Minor)$($RawVersion.Build)$($RawVersion.Revision.ToString('D3'))"

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
