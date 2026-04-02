$Global:DumplingsStorage.ChrolisApps = Invoke-WebRequest -Uri 'https://www.thorlabs.com/software_pages/check_updates.cfm?ItemID=CHROLIS' | Read-ResponseContent | ConvertFrom-Xml
