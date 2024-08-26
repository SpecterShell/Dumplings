# $Object1 = (Invoke-WebRequest -Uri 'https://www.advanced-ip-scanner.com/checkupdate.php').Content
$Object1 = Invoke-WebRequest -Uri 'https://www.advanced-ip-scanner.com/download/' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.SelectSingleNode('//a[@class="download_link" and contains(@href, "Advanced_IP_Scanner")]').Attributes['href'].Value
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $NestedInstallerFileRoot = New-TempFolder
    7z.exe e -aoa -ba -bd '-t#' -o"${NestedInstallerFileRoot}" $InstallerFile '2.msi' | Out-Host
    $NestedInstallerFile = Join-Path $NestedInstallerFileRoot '2.msi'

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $this.CurrentState.Installer[0]['ProductCode'] = $NestedInstallerFile | Read-ProductCodeFromMsi
        UpgradeCode   = $NestedInstallerFile | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
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
