$Global:DumplingsStorage.SapMachineBuilds = (Invoke-WebRequest -Uri 'https://sapmachine.io/assets/data/sapmachine-releases-website.json').Content | ConvertFrom-Json -AsHashtable
