$Global:DumplingsStorage.KIRDownloadPage = Invoke-WebRequest -Uri 'https://www.elektronicznypodpis.pl/en/applications-and-drivers' | ConvertFrom-Html
