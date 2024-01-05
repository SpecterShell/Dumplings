$LocalStorage['JetBrainsApps'] = [ordered]@{}

$this.Config.Products.GetEnumerator() |
  # Map
  ForEach-Object -Process { foreach ($Type in $_.Value) { @{ Code = $_.Name; Type = $Type } } } |
  # Shuffle
  Group-Object -Property { $_.Type } |
  # Reduce
  ForEach-Object -Process {
    $Object1 = Invoke-RestMethod -Uri "https://data.services.jetbrains.com/products/releases?latest=true&type=$($_.Name)&code=$($_.Group.Code -join '&code=')"
    foreach ($Code in $_.Group.Code) {
      if (-not $LocalStorage.JetBrainsApps.Contains($Code)) {
        $LocalStorage.JetBrainsApps[$Code] = [ordered]@{}
      }
      $LocalStorage.JetBrainsApps.$Code[$_.Name] = $Object1.$Code[0]
    }
  }
