$Global:DumplingsStorage.KinesisPrefix = 'https://www.thorlabs.com/software_pages/ViewSoftwarePage.cfm?Code=Motion_Control'
$Global:DumplingsStorage.KinesisDownloadPage = Invoke-WebRequest -Uri $Global:DumplingsStorage.KinesisPrefix
