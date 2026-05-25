$Global:DumplingsStorage.AGTEKDownloadPage = Invoke-WebRequest -Uri 'https://agtek.com/services-support/product-downloads/' | ConvertFrom-Html
$Global:DumplingsStorage.AGTEKAppInstallerSource = Invoke-RestMethod -Uri 'https://agtek.s3.amazonaws.com/Agtek/EUkxrlekp0K4'
