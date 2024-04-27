$Global:DumplingsStorage.AzulZuluBuilds = Invoke-RestMethod -Uri 'https://api.azul.com/metadata/v1/zulu/packages/?os=windows&archive_type=msi&latest=true&release_status=ga&availability_types=CA'
