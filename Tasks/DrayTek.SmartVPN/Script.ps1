$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://www.draytek.com/products/smart-vpn-client/' | Join-String -Separator "`n" | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('Smart%20VPN%20Client') } catch {} }, 'First')[0].href | ConvertTo-UnescapedUri
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
      $Installer['NestedInstallerFiles'] = @(
        [ordered]@{
          RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.msi') }, 'First')[0].FullName.Replace('/', '\')
        }
      )
      $ZipFile.Dispose()
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('Smart%20VPN%20Client') -and $_.href.Contains('release%20note') } catch {} }, 'First')[0].href
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
