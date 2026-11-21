$Global:DumplingsStorage.IdeameritDownloadPage = Invoke-WebRequest -Uri 'https://www.datensen.com/download.html' | ConvertFrom-Html
