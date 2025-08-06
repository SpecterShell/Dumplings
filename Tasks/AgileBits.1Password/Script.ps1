$Object1 = Invoke-RestMethod -Uri "https://app-updates.agilebits.com/check/2/10.0.22000/x86_64/OPW8/en/$($this.LastState.Contains('RawVersion') ? $this.LastState.RawVersion: '81026039')/A1/N"

if ($Object1.available -eq '0') {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += $InstallerEXE = [ordered]@{
  Query                  = [ordered]@{
    Architecture  = 'x64'
    InstallerType = 'exe'
  }
  InstallerUrl           = "https://downloads.1password.com/win/1PasswordSetup-$($this.CurrentState.Version).exe"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $this.CurrentState.Version
    }
  )
}
$this.CurrentState.Installer += $InstallerMSI = [ordered]@{
  Query                  = [ordered]@{
    Architecture  = 'x64'
    InstallerType = 'msi'
  }
  InstallerUrl           = "https://downloads.1password.com/win/1PasswordSetup-$($this.CurrentState.Version).msi"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $this.CurrentState.Version
    }
  )
}
$this.CurrentState.Installer += $InstallerMSIX = [ordered]@{
  Query        = [ordered]@{
    InstallerType = 'msix'
  }
  InstallerUrl = "https://downloads.1password.com/win/1PasswordSetup-$($this.CurrentState.Version).msixbundle"
}
# If the ARM64 installer already exists, don't check again and simply add it to the list
if ($this.LastState['Mode']) {
  $this.CurrentState.Installer += [ordered]@{
    Query                  = [ordered]@{
      Architecture  = 'x64'
      InstallerType = 'exe'
    }
    Architecture           = 'arm64'
    InstallerUrl           = "https://downloads.1password.com/win/arm64/1PasswordSetup-$($this.CurrentState.Version)-arm64.exe"
    AppsAndFeaturesEntries = @(
      [ordered]@{
        DisplayVersion = $this.CurrentState.Version
      }
    )
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
      Query                  = [ordered]@{
        Architecture  = 'x64'
        InstallerType = 'exe'
      }
      Architecture           = 'arm64'
      InstallerUrl           = $InstallerUrlArm64
      AppsAndFeaturesEntries = @(
        [ordered]@{
          DisplayVersion = $this.CurrentState.Version
        }
      )
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
    $this.InstallerFiles[$InstallerEXE.InstallerUrl] = $InstallerEXEFile = Get-TempFile -Uri $InstallerEXE.InstallerUrl
    # RawVersion
    $RawVersion = $InstallerEXEFile | Read-FileVersionRawFromExe
    $this.CurrentState.RawVersion = "$($RawVersion.Major)$($RawVersion.Minor)$($RawVersion.Build)$($RawVersion.Revision.ToString('D3'))"

    $this.InstallerFiles[$InstallerMSI.InstallerUrl] = Get-TempFile -Uri $InstallerMSI.InstallerUrl

    $this.InstallerFiles[$InstallerMSIX.InstallerUrl] = $InstallerMSIXFile = Get-TempFile -Uri $InstallerMSIX.InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = ($InstallerMSIXFile | Get-MSIXManifest | ConvertFrom-Xml).GetElementsByTagName('Package')[0].Version

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
