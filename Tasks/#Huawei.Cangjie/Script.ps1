$Global:DumplingsStorage.CangjiePrefix = 'https://cangjie-lang.cn/download'
$Global:DumplingsStorage.CangjieDownloadPage = Invoke-WebRequest -Uri $Global:DumplingsStorage.CangjiePrefix | ConvertFrom-Html
$Global:DumplingsStorage.CangjieSTSPrefix = Join-Uri 'https://cangjie-lang.cn/download' $Global:DumplingsStorage.CangjieDownloadPage.SelectSingleNode('//div[@class="download-version-item" and contains(.//div[@class="download-version-item-n"], "STS Version")]//a').Attributes['href'].Value
$Global:DumplingsStorage.CangjieSTSPage = Invoke-WebRequest -Uri $Global:DumplingsStorage.CangjieSTSPrefix | ConvertFrom-Html
$Global:DumplingsStorage.CangjieVersionJS = Invoke-RestMethod -Uri $Global:DumplingsStorage.CangjieSTSPage.SelectSingleNode('//script[contains(@src, "version") and contains(@src, ".js")]').Attributes['src'].Value
