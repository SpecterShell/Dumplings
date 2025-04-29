$Global:DumplingsStorage.DevolutionsApps = Invoke-RestMethod -Uri 'https://devolutions.net/products.htm' | ConvertFrom-Ini
