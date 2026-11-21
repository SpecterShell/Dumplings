$Global:DumplingsStorage.TrackerSoftwareApps = Invoke-WebRequest -Uri 'https://www.pdf-xchange.com/updater/UpdaterData.xml' | Read-ResponseContent | ConvertFrom-Xml
