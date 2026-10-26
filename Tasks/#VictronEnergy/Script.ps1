$Global:DumplingsStorage.VictronEnergyWebsitePrefix = 'https://www.victronenergy.com'
$Global:DumplingsStorage.VictronEnergySoftwareApiPrefix = 'https://www-api.victronenergy.com/www2-api/v1/software/'

$Catalog = [System.Collections.Generic.List[object]]::new()
$Page = $Global:DumplingsStorage.VictronEnergySoftwareApiPrefix
while ($Page) {
  $Object1 = Invoke-RestMethod -Uri $Page
  $Catalog.AddRange([object[]]@($Object1.results))
  $Page = $Object1.next
}

$Global:DumplingsStorage.VictronEnergySoftwareCatalog = $Catalog
