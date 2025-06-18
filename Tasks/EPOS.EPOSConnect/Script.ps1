$Prefix = 'https://www.eposaudio.com/en/us/software/epos-connect'
$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent $Prefix | Join-String -Separator "`n" | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += $InstallerEXE = [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = $Object1.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}
$VersionEXE = [regex]::Match($InstallerEXE.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerWiX = [ordered]@{
  InstallerType       = 'zip'
  NestedInstallerType = 'wix'
  InstallerUrl        = $Object1.Where({ try { $_.href.EndsWith('msi.zip') } catch {} }, 'First')[0].href
}
$VersionWiX = [regex]::Match($InstallerWiX.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionEXE -ne $VersionWiX) {
  $this.Log("EXE version: ${VersionEXE}")
  $this.Log("WiX version: ${VersionWiX}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerEXE.InstallerUrl, '(\d+(?:\.\d+){3,})').Groups[1].Value

$InstallerWiX['NestedInstallerFiles'] = @(
  [ordered]@{
    RelativeFilePath = "EPOSConnect_$($this.CurrentState.Version).msi"
  }
)

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = Join-Uri $Prefix $Object1.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('release-notes') -and $_.href.Contains($VersionEXE) } catch {} }, 'First')[0].href
      }
      # Documentations
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'Documentations'
        Value = @(
          [ordered]@{
            DocumentLabel = 'Manual'
            DocumentUrl   = Join-Uri $Prefix $Object1.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('manual') } catch {} }, 'First')[0].href
          }
        )
      }
      # Documentations (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = '手册'
            DocumentUrl   = Join-Uri $Prefix $Object1.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('manual') } catch {} }, 'First')[0].href
          }
        )
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
