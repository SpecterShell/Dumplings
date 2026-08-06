$Global:DumplingsStorage.CardExchangeDownloadPage = Invoke-WebRequest -Uri 'https://cardexchangeid.com/support/resources/downloads' | ConvertFrom-Html
