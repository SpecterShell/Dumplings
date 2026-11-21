$Object1 = $Global:DumplingsStorage.KIRDownloadPage.SelectSingleNode('//div[@class="drivers__text" and contains(., "SzafirHost") and contains(., "32-bit")]')
$Object2 = $Global:DumplingsStorage.KIRDownloadPage.SelectSingleNode('//div[@class="drivers__text" and contains(., "SzafirHost") and contains(., "64-bit")]')

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('./following-sibling::a[contains(@class, "drivers__link")]').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri $Object2.SelectSingleNode('./following-sibling::a[contains(@class, "drivers__link")]').Attributes['href'].Value
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'Header'
    HeaderName  = 'x-goog-hash'
    SelectValue = { param($Values) @($Values) -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_.StartsWith('md5=') } | ForEach-Object { $_.Substring(4) } }
    ReadVersion = { param($Path) Read-ProductVersionFromMsi -Path $Path }
  })

$this.CompleteInstallerUpdates($Result)
