$Global:DumplingsStorage.LinklySoftwarePage = Invoke-WebRequest -Uri 'https://linkly.com.au/resources-support/software/'
$Global:DumplingsStorage.LinklySoftwarePageObject = $Global:DumplingsStorage.LinklySoftwarePage | ConvertFrom-Html
