$Global:DumplingsStorage.IgneusPrefix = 'https://www.igneusinc.com/download.html'
$Global:DumplingsStorage.IgneusDownloadPage = Invoke-WebRequest -Uri $Global:DumplingsStorage.IgneusPrefix
