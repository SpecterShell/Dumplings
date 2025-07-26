<#
Available links:
https://www.acs.com.hk/en/driver/368/acm1252u-y3-usb-nfc-reader-module-with-detachable-antenna-board/
https://www.acs.com.hk/en/driver/412/acm1252u-z2-small-nfc-reader-module/
https://www.acs.com.hk/en/driver/369/acm1281u-c7-usb-contactless-reader-module-with-sam-slot/
https://www.acs.com.hk/en/driver/496/acm39u-y3-smart-card-reader-module/
#>
$Prefix = 'https://www.acs.com.hk/en/driver/368/acm1252u-y3-usb-nfc-reader-module-with-detachable-antenna-board/'
$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent $Prefix | Join-String -Separator "`n" | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl = Join-Uri $Prefix $Object1.Where({ try { $_.href.Contains('acsunidrv') -and $_.href.EndsWith('.zip') -and $_.href.Contains('windows') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact([regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(20\d{6})').Groups[1].Value, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = New-TempFile
    curl -fsSLA $DumplingsInternetExplorerUserAgent -o $InstallerFile $this.CurrentState.Installer[0].InstallerUrl | Out-Host
    $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
    $InstallerX86['NestedInstallerFiles'] = @(
      [ordered]@{
        RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.msi') -and $_.FullName.Contains('x86') }, 'First')[0].FullName.Replace('/', '\')
      }
    )
    $InstallerX64['NestedInstallerFiles'] = @(
      [ordered]@{
        RelativeFilePath = $ZipFile.Entries.Where({ $_.FullName.EndsWith('.msi') -and $_.FullName.Contains('x64') }, 'First')[0].FullName.Replace('/', '\')
      }
    )
    $ZipFile.Dispose()

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
