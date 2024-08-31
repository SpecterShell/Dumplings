$Object1 = Invoke-WebRequest -Uri 'https://www.azul.com/products/components/icedtea-web/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.Links | Where-Object -FilterScript { ($_ | Get-Member -Name 'href' -ErrorAction SilentlyContinue) -and $_.href.EndsWith('.msi') -and $_.href.Contains('win') -and $_.href.Contains('i686') } | Select-Object -First 1 | Select-Object -ExpandProperty 'href'
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Links | Where-Object -FilterScript { ($_ | Get-Member -Name 'href' -ErrorAction SilentlyContinue) -and $_.href.EndsWith('.msi') -and $_.href.Contains('win') -and $_.href.Contains('x64') } | Select-Object -First 1 | Select-Object -ExpandProperty 'href'
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerX64.InstallerUrl, '(\d+(?:\.\d+){2,}-\d+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $InstallerX64.InstallerUrl

    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi
    # InstallerSha256
    $InstallerX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries + ProductCode
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode = $InstallerX64['ProductCode'] = $InstallerFile | Read-ProductCodeFromMsi
        UpgradeCode = $InstallerFile | Read-UpgradeCodeFromMsi
      }
    )

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
