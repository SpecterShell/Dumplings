$Object1 = Invoke-WebRequest -Uri 'https://www.veeam.com/products/downloads/latest-version.html' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//tbody[contains(./tr[@name="product-name"], "Veeam Agent for Microsoft Windows")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.SelectSingleNode('./tr[@name="product-download"]').InnerText, 'Version\s*:\s*(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download2.veeam.com/VAW/v6/VeeamAgentWindows_$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('./tr[@name="product-download"]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'Endpoint\Endpoint\Veeam_B&R_Endpoint_x64.msi' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'Veeam_B&R_Endpoint_x64.msi'
    # AppsAndFeaturesEntries + ProductCode
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }

      $Object3 = Invoke-RestMethod -Uri 'https://www.veeam.com/services/veeam/technical-documents?resourceType=resourcetype:techdoc/releasenotes&productId=41'
      $ReleaseNotesUrl = $Object3.payload.products.Where({ $_.productId -eq 41 }, 'First')[0].documentGroups.Where({ $_.resourceType -eq 'resourcetype:techdoc/releasenotes' }, 'First')[0].documents[0].links.html
      if ($ReleaseNotesUrl.Contains($this.CurrentState.Version.Split('.')[0..2] -join '_')) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object3.payload.products.Where({ $_.productId -eq 41 }, 'First')[0].documentGroups.Where({ $_.resourceType -eq 'resourcetype:techdoc/releasenotes' }, 'First')[0].documents[0].links.html
        }
      } else {
        $this.Log("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
