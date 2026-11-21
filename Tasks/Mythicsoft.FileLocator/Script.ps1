$Prefix = 'https://www.mythicsoft.com/filelocator/download/'
$Object1 = curl -fSsLA $DumplingsInternetExplorerUserAgent $Prefix | Join-String -Separator "`n" | Get-EmbeddedLinks

# x86
$InstallerUrlX86 = $Object1.Where({ $_.href -match 'filelocator_x86_msi_(\d+)\.zip$' }, 'First')[0].href
$VersionX86 = $Matches[1]

# x64
$InstallerUrlX64 = $Object1.Where({ $_.href -match 'filelocator_x64_msi_(\d+)\.zip$' }, 'First')[0].href
$VersionX64 = $Matches[1]

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: $VersionX86, x64: $VersionX64", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = Join-Uri $Prefix $InstallerUrlX86
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "filelocator_x86_$($this.CurrentState.Version).msi"
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = Join-Uri $Prefix $InstallerUrlX64
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "filelocator_x64_$($this.CurrentState.Version).msi"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.AgentRansack[$this.CurrentState.Version].ReleaseTime | Get-Date -AsUTC

      if ($Global:DumplingsStorage.Contains('AgentRansack') -and $Global:DumplingsStorage.AgentRansack.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.AgentRansack[$this.CurrentState.Version].ReleaseNotes
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
