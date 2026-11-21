$Global:DumplingsStorage.AppleProducts = Invoke-RestMethod -Uri 'https://swcatalog.apple.com/content/catalogs/others/index-windows-1.sucatalog' | ConvertFrom-PropertyList
