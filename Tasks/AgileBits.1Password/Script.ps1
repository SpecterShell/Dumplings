$Object1 = Invoke-RestMethod -Uri "https://app-updates.agilebits.com/check/2/10.0.22000/x86_64/OPW8/en/$($this.LastState.Contains('RawVersion') ? $this.LastState.RawVersion: '81026039')/A1/N"

if ($Object1.available -eq '0') {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Query        = [ordered]@{
    Architecture  = 'x64'
    InstallerType = 'exe'
  }
  InstallerUrl = "https://downloads.1password.com/win/1PasswordSetup-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  Query        = [ordered]@{
    Architecture  = 'x64'
    InstallerType = 'msi'
  }
  InstallerUrl = "https://downloads.1password.com/win/1PasswordSetup-$($this.CurrentState.Version).msi"
}
$this.CurrentState.Installer += [ordered]@{
  Query        = [ordered]@{
    InstallerType = 'msix'
  }
  InstallerUrl = "https://downloads.1password.com/win/1PasswordSetup-$($this.CurrentState.Version).msixbundle"
}
# If the ARM64 installer already exists, don't check again and simply add it to the list
if ($this.LastState['Mode']) {
  $this.CurrentState.Installer += [ordered]@{
    Query        = [ordered]@{
      Architecture  = 'x64'
      InstallerType = 'exe'
    }
    Architecture = 'arm64'
    InstallerUrl = "https://downloads.1password.com/win/arm64/1PasswordSetup-$($this.CurrentState.Version)-arm64.exe"
  }
  # Mode
  $this.CurrentState.Mode = $true
} else {
  try {
    # Check if the ARM64 installer exists
    $InstallerUrlArm64 = "https://downloads.1password.com/win/arm64/1PasswordSetup-$($this.CurrentState.Version)-arm64.exe"
    $null = Invoke-WebRequest -Uri $InstallerUrlArm64 -Method Head
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Query        = [ordered]@{
        Architecture  = 'x64'
        InstallerType = 'exe'
      }
      Architecture = 'arm64'
      InstallerUrl = $InstallerUrlArm64
    }
    # Mode
    $this.CurrentState.Mode = $true
  } catch {
    $this.Log("${InstallerUrlArm64} doesn't exist, the ARM64 installer will be discarded", 'Warning')
    # Mode
    $this.CurrentState.Mode = $false
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RawVersion
    $RawVersion = $InstallerFile | Read-FileVersionRawFromExe
    $this.CurrentState.RawVersion = "$($RawVersion.Major)$($RawVersion.Minor)$($RawVersion.Build)$($RawVersion.Revision.ToString('D3'))"

    $this.InstallerFiles[$this.CurrentState.Installer[1].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[1].InstallerUrl

    $this.Print()
    $this.Write()
  }
  { $_.Contains('Changed') -and -not $_.Contains('Updated') } {
    $this.Config.IgnorePRCheck = $true
  }
  'Changed|Updated' {
    $this.Message()
    $this.Submit()
  }
}
