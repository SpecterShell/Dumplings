$LocalStorage['JetBrainsApps'] = [ordered]@{}

foreach ($Type in $this.Config.Products.GetEnumerator()) {
  $Object1 = Invoke-RestMethod -Uri "https://data.services.jetbrains.com/products/releases?latest=true&type=$($Type.Name)&code=$($Type.Value -join '&code=')"
  foreach ($Code in $Type.Value) {
    if (-not $LocalStorage.JetBrainsApps.Contains($Code)) {
      $LocalStorage.JetBrainsApps[$Code] = [ordered]@{}
    }
    $LocalStorage.JetBrainsApps.$Code[$Type.Name] = $Object1.$Code[0]
  }
}
