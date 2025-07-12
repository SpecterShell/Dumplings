$Global:DumplingsStorage.DMTDownloadPageUrl = 'https://www.dmt.dk/software-downloads.html'
$Global:DumplingsStorage.DMTDownloadPage = Invoke-WebRequest -Uri $Global:DumplingsStorage.DMTDownloadPageUrl
