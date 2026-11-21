$Global:DumplingsStorage.iChemLabsPrefix = 'https://www.ichemlabs.com/download'
$Global:DumplingsStorage.iChemLabsApps = Invoke-WebRequest -Uri $Global:DumplingsStorage.iChemLabsPrefix
