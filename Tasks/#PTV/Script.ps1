$Global:DumplingsStorage.PTVDownloads = Invoke-WebRequest -Uri 'https://cgi.ptvgroup.com/json/downloads-en.json' | Read-ResponseContent | ConvertFrom-Json
