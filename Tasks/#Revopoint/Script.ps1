$Global:DumplingsStorage.RevopointDownloadPage = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://www.revopoint3d.com/pages/support-download' | Join-String -Separator "`n" | ConvertFrom-Html
