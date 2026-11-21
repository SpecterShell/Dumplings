$Global:DumplingsStorage.PlenomDownloadPage = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://www.plenom.com/downloads/download-software/' | Join-String -Separator "`n" | ConvertFrom-Html
