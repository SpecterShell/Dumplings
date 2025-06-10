$Global:DumplingsStorage.LocklizardApps = Invoke-RestMethod -Uri 'https://updates.locklizard.com/Update.inf' | ConvertFrom-Ini
