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

    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $InstallerFileExtracted = New-TempFolder
    Start-Process -FilePath $InstallerFile -ArgumentList @('/ExtractCab') -WorkingDirectory $InstallerFileExtracted -Wait
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'SupportFiles' 'CodeMeterRuntime64.msi'
    # ProductCode
    $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

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
