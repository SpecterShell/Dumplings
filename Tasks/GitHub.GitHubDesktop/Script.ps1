# Installer
$this.CurrentState.Installer += $InstallerEXE = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = Get-RedirectedUrl -Uri 'https://central.github.com/deployments/desktop/desktop/latest/win32'
}
$VersionEXE = [regex]::Match($InstallerEXE.InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value -creplace '(?<=\d)(\d)', '.$1'

$this.CurrentState.Installer += $InstallerWiX = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = Get-RedirectedUrl -Uri 'https://central.github.com/deployments/desktop/desktop/latest/win32?format=msi'
}
$VersionWiX = [regex]::Match($InstallerWiX.InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value -creplace '(?<=\d)(\d)', '.$1'

if ($VersionEXE -ne $VersionWiX) {
  $this.Log("EXE version: ${VersionEXE}")
  $this.Log("WiX version: ${VersionWiX}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionWiX

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object1 = Invoke-RestMethod -Uri 'https://central.github.com/deployments/desktop/desktop/changelog.json'

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
