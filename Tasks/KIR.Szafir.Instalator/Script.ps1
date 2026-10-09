$Object1 = $Global:DumplingsStorage.KIRDownloadPage.SelectSingleNode('//div[@class="drivers__text" and contains(., "Szafir installation set") and contains(., "Windows")]')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('./following-sibling::a[contains(@class, "drivers__link")]').Attributes['href'].Value
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'Header'
    HeaderName  = 'x-goog-hash'
    SelectValue = { param($Values) @($Values) -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_.StartsWith('md5=') } | ForEach-Object { $_.Substring(4) } }
    ReadVersion = { param($Path) Read-ProductVersionFromMsi -Path $Path }
  })

$this.CompleteInstallerUpdates($Result)
