$Global:DumplingsStorage.BenthicSoftwarePrefix = 'https://www.benthicsoftware.com/downloads.html'
$Global:DumplingsStorage.BenthicSoftwareApps = Invoke-WebRequest -Uri $Global:DumplingsStorage.BenthicSoftwarePrefix
