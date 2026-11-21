$Global:DumplingsStorage.PostgreSQLDownloadPage = Invoke-WebRequest -Uri 'https://www.enterprisedb.com/downloads/postgres-postgresql-downloads' | ConvertFrom-Html
