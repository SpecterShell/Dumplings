# Installer
$this.CurrentState.Installer += $InstallerEXE = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = Get-RedirectedUrl -Uri 'https://central.github.com/deployments/desktop/desktop/latest/win32'
}
$this.CurrentState.Installer += $InstallerWiX = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = Get-RedirectedUrl -Uri 'https://central.github.com/deployments/desktop/desktop/latest/win32?format=msi'
}

$VersionX86 = [regex]::Match($InstallerEXE.InstallerUrl, '(\d+\.\d+\.\d+(?:\.\d+)*)').Groups[1].Value -creplace '(?<=\d)(\d)', '.$1'
$VersionX64 = [regex]::Match($InstallerWiX.InstallerUrl, '(\d+\.\d+\.\d+(?:\.\d+)*)').Groups[1].Value -creplace '(?<=\d)(\d)', '.$1'

if ($VersionX86 -ne $VersionX64) {
  $this.Log('Distinct versions detected', 'Warning')
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Distinct versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerEXE['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayVersion = $this.CurrentState.Version
      }
    )

    $InstallerWiXFile = Get-TempFile -Uri $InstallerWiX.InstallerUrl
    $InstallerWiX['InstallerSha256'] = (Get-FileHash -Path $InstallerWiXFile -Algorithm SHA256).Hash
    $InstallerWiX['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = 'GitHub Desktop Deployment Tool'
        DisplayVersion = $InstallerWiXFile | Read-ProductVersionFromMsi
        ProductCode    = $InstallerWiX['ProductCode'] = $InstallerWiXFile | Read-ProductCodeFromMsi
        UpgradeCode    = $InstallerWiXFile | Read-UpgradeCodeFromMsi
      }
    )

    try {
      $Object2 = Invoke-RestMethod -Uri 'https://central.github.com/deployments/desktop/desktop/changelog.json'

      $ReleaseNotesObject = $Object2.Where({ $_.version -eq $this.CurrentState.Version }, 'First')
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
