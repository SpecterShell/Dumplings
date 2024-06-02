$Model = $Global:DumplingsSecret.DELL_MODEL

$CabPath = Get-TempFile -Uri 'https://downloads.dell.com/catalog/CatalogIndexPC.cab'
expand.exe -R $CabPath | Out-Host
$Object1 = Join-Path $CabPath '..' 'CatalogIndexPC.xml' | Get-Item | Get-Content -Raw | ConvertFrom-Xml

$CatalogPath = $Object1.ManifestIndex.GroupManifest.Where({ $_.SupportedSystems.Brand.Model.systemID -eq $Model }, 'First')[0].ManifestInformation.path
$CatalogName = (Split-Path -Path $CatalogPath -Leaf) -replace '\.cab$', '.xml'

$CabPath = Get-TempFile -Uri "https://downloads.dell.com/${CatalogPath}"
expand.exe -R $CabPath | Out-Null
$Global:DumplingsStorage.DellCatalog = Join-Path $CabPath '..' $CatalogName | Get-Item | Get-Content -Raw | ConvertFrom-Xml

# Precedence Catalog
$CabPath = Get-TempFile -Uri 'https://dellupdater.dell.com/non_du/ClientService/Catalog/Platform/PrecedenceCatalog.cab'
expand.exe -R $CabPath | Out-Host

$Global:DumplingsStorage.DellPrecedenceCatalog = Join-Path $CabPath '..' 'PrecedenceCatalog.xml' | Get-Item | Get-Content -Raw | ConvertFrom-Xml
