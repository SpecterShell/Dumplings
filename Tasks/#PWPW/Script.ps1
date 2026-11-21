$Global:DumplingsStorage.PWPWDownloadPagePrefix = 'https://sigillum.pl/pliki'
$Global:DumplingsStorage.PWPWDownloadPage = Invoke-WebRequest -Uri $Global:DumplingsStorage.PWPWDownloadPagePrefix
