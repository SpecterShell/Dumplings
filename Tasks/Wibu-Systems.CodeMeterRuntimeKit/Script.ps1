$Prefix = 'https://www.wibu.com/support/user/user-software.html'
$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//div[@class="media__body" and ./h3[contains(text(), "CodeMeter User Runtime for Windows")]]')
$Object3 = $Object2.SelectSingleNode('.//optgroup[@label="Windows 32/64-Bit"]/option')

# Version
$this.CurrentState.Version = [regex]::Match($Object3.InnerText, 'Version (\S+)').Groups[1].Value

$InstallerPageUrl = Join-Uri $Prefix $Object2.SelectSingleNode(".//div[contains(@class, 'tx-wibuDownloads-download-list-selection-content-$($Object3.Attributes['value'].Value)')]//a").Attributes['href'].Value
$Object4 = Invoke-WebRequest -Uri $InstallerPageUrl | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl = (Join-Uri $InstallerPageUrl $Object4.SelectSingleNode('//a[@id="tx-wibuDownloads-downloadNotice-directLink"]').Attributes['href'].Value | ConvertTo-UnescapedUri) -replace '&?tx_wibudownloads_downloadlist\[useAwsS3\]=0'
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl
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
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'SupportFiles' 'CodeMeterRuntime32.msi'
    # ProductCode
    $InstallerX86['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $InstallerX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    $InstallerFile3 = Join-Path $InstallerFileExtracted 'SupportFiles' 'CodeMeterRuntime64.msi'
    # ProductCode
    $InstallerX64['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
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
