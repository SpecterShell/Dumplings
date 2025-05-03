$Global:DumplingsStorage.DelineaDownloadPage = Invoke-WebRequest -Uri 'https://docs.delinea.com/online-help/privilege-manager/install/sw-downloads.htm' | ConvertFrom-Html
