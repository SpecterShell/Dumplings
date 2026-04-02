$IndexCabPath = Get-TempFile -Uri 'https://downloads.dell.com/catalog/CatalogIndexPC.cab'
expand.exe -R $IndexCabPath | Out-Host
$Index = Join-Path $IndexCabPath '..' 'CatalogIndexPC.xml' | Get-Item | Get-Content -Raw | ConvertFrom-Xml

# Catalog #1
$Model = $Global:DumplingsSecret.DellModel
$CatalogCabUri = 'https://downloads.dell.com/' + $Index.ManifestIndex.GroupManifest.Where({ $_.SupportedSystems.Brand.Model.systemID -eq $Model }, 'First')[0].ManifestInformation.path
$CatalogName = (Split-Path -Path $CatalogCabUri -Leaf) -replace '\.cab$', '.xml'
$CatalogCabPath = Get-TempFile -Uri $CatalogCabUri
expand.exe -R $CatalogCabPath | Out-Null
$Global:DumplingsStorage.DellCatalog = Join-Path $CatalogCabPath '..' $CatalogName | Get-Item | Get-Content -Raw | ConvertFrom-Xml

# Catalog #2
$Model2 = $Global:DumplingsSecret.DellModel2
$Catalog2CabUri = 'https://downloads.dell.com/' + $Index.ManifestIndex.GroupManifest.Where({ $_.SupportedSystems.Brand.Model.systemID -eq $Model2 }, 'First')[0].ManifestInformation.path
$Catalog2Name = (Split-Path -Path $Catalog2CabUri -Leaf) -replace '\.cab$', '.xml'
$Catalog2CabPath = Get-TempFile -Uri $Catalog2CabUri
expand.exe -R $Catalog2CabPath | Out-Null
$Global:DumplingsStorage.DellCatalog2 = Join-Path $Catalog2CabPath '..' $Catalog2Name | Get-Item | Get-Content -Raw | ConvertFrom-Xml

# Precedence Catalog
$PrecedenceCatalogCabPath = Get-TempFile -Uri 'https://dellupdater.dell.com/non_du/ClientService/Catalog/Platform/PrecedenceCatalog.cab'
expand.exe -R $PrecedenceCatalogCabPath | Out-Host
$Global:DumplingsStorage.DellPrecedenceCatalog = Join-Path $PrecedenceCatalogCabPath '..' 'PrecedenceCatalog.xml' | Get-Item | Get-Content -Raw | ConvertFrom-Xml
