# Installer
$this.CurrentState.Installer += $InstallerX64EXE = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = Get-RedirectedUrl -Uri 'https://central.github.com/deployments/desktop/desktop/latest/win32?env=beta'
}
$VersionX64EXE = [regex]::Match($InstallerX64EXE.InstallerUrl, '(\d+(?:\.\d+){2,}(?:-beta\d+){0,1})').Groups[1].Value

$this.CurrentState.Installer += $InstallerX64WiX = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = Get-RedirectedUrl -Uri 'https://central.github.com/deployments/desktop/desktop/latest/win32?env=beta&format=msi'
}
$VersionX64WiX = [regex]::Match($InstallerX64WiX.InstallerUrl, '(\d+(?:\.\d+){2,}(?:-beta\d+){0,1})').Groups[1].Value

$this.CurrentState.Installer += $InstallerARM64EXE = [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'exe'
  InstallerUrl  = Get-RedirectedUrl -Uri 'https://central.github.com/deployments/desktop/desktop/latest/win32-arm64?env=beta'
}
$VersionARM64EXE = [regex]::Match($InstallerARM64EXE.InstallerUrl, '(\d+(?:\.\d+){2,}(?:-beta\d+){0,1})').Groups[1].Value

$this.CurrentState.Installer += $InstallerARM64WiX = [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
  InstallerUrl  = Get-RedirectedUrl -Uri 'https://central.github.com/deployments/desktop/desktop/latest/win32-arm64?env=beta&format=msi'
}
$VersionARM64WiX = [regex]::Match($InstallerARM64WiX.InstallerUrl, '(\d+(?:\.\d+){2,}(?:-beta\d+){0,1})').Groups[1].Value

if (@(@($VersionX64EXE, $VersionX64WiX, $VersionARM64EXE, $VersionARM64WiX) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("x64 EXE version: ${VersionX64EXE}")
  $this.Log("x64 MSI version: ${VersionX64WiX}")
  $this.Log("arm64 EXE version: ${VersionARM64EXE}")
  $this.Log("arm64 MSI version: ${VersionARM64WiX}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64WiX

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object1 = Invoke-RestMethod -Uri 'https://central.github.com/deployments/desktop/desktop/changelog.json?env=beta'

      $ReleaseNotesObject = $Object1.Where({ $_.version -eq $this.CurrentState.Version }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesObject.pub_date | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.notes | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
