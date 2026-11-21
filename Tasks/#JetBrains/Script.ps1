$Global:DumplingsStorage['JetBrainsApps'] = [ordered]@{}

$this.Config.Products.GetEnumerator() |
  # Map
  ForEach-Object -Process { foreach ($Type in $_.Value) { @{ Code = $_.Name; Type = $Type } } } |
  # Shuffle
  Group-Object -Property { $_.Type } |
  # Reduce
  ForEach-Object -Process {
    $Object1 = Invoke-RestMethod -Uri "https://data.services.jetbrains.com/products/releases?latest=true&type=$($_.Name)&code=$($_.Group.Code -join ',')"
    foreach ($Code in $_.Group.Code) {
      if (-not $Global:DumplingsStorage.JetBrainsApps.Contains($Code)) {
        $Global:DumplingsStorage.JetBrainsApps[$Code] = [ordered]@{}
      }
      if ($Object1.$Code.Count -gt 0) {
        $Global:DumplingsStorage.JetBrainsApps.$Code[$_.Name] = $Object1.$Code[0]
      } else {
        $this.Log("No releases found for ${Code} ($($_.Name))", 'Warning')
      }
    }
  }
