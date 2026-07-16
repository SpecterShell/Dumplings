$Prefix = 'https://www.wibu.com/support/user/user-software.html'
$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//div[@class="media__body" and ./h3[contains(text(), "CodeMeter User Runtime for Windows")]]')
$Object3 = $Object2.SelectSingleNode('.//optgroup[@label="Windows 64-bit"]/option')

# Version
$this.CurrentState.Version = [regex]::Match($Object3.InnerText, 'Version (\S+)').Groups[1].Value

$InstallerPageUrl = Join-Uri $Prefix $Object2.SelectSingleNode(".//div[contains(@class, 'tx-wibuDownloads-download-list-selection-content-$($Object3.Attributes['value'].Value)')]//a").Attributes['href'].Value
$Object4 = Invoke-WebRequest -Uri $InstallerPageUrl | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = (Join-Uri $InstallerPageUrl $Object4.SelectSingleNode('//a[@id="tx-wibuDownloads-downloadNotice-directLink"]').Attributes['href'].Value | ConvertTo-UnescapedUri) -replace '&?tx_wibudownloads_downloadlist\[useAwsS3\]=0'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object3.InnerText, '(20\d{2}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $DotNetInstallerInfo = Get-DotNetInstallerInfo -Path $InstallerFile
    $MsiPayloads = @($DotNetInstallerInfo.ExecutedPayloads | Where-Object { [System.IO.Path]::GetExtension($_) -ieq '.msi' })
    if ($MsiPayloads.Count -ne 1) { throw "Expected one dotNetInstaller MSI payload, but found $($MsiPayloads.Count)" }
    $InstallerFileExtracted = New-TempFolder
    try {
      $ExtractedMsiFiles = @(Expand-DotNetInstaller -Path $InstallerFile -DestinationPath $InstallerFileExtracted -Name $MsiPayloads[0])
      if ($ExtractedMsiFiles.Count -ne 1) { throw "Expected one extracted dotNetInstaller MSI, but found $($ExtractedMsiFiles.Count)" }
      $MsiInfo = Get-MsiInstallerInfo -Path $ExtractedMsiFiles[0]
      # RealVersion
      $this.CurrentState.RealVersion = $MsiInfo.ProductVersion
      # ProductCode
      $this.CurrentState.Installer[0]['ProductCode'] = $MsiInfo.ProductCode
      # AppsAndFeaturesEntries
      $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          UpgradeCode   = $MsiInfo.UpgradeCode
          InstallerType = 'msi'
        }
      )
    } finally {
      Remove-Item -LiteralPath $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
