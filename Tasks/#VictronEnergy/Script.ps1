$Global:DumplingsStorage.VictronEnergyPrefix = 'https://www.victronenergy.com/support-and-downloads/software'
$Global:DumplingsStorage.VictronEnergyDownloadPage = Invoke-WebRequest -Uri $Global:DumplingsStorage.VictronEnergyPrefix
