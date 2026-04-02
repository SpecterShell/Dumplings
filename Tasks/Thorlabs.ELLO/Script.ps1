$Query = @'
query {
  slugInfo(
    slug: "software-pages/ELL"
    cultureName: "en-US"
    storeId: "Thorlabs-Website"
  ) {
    entityInfo {
      id
    }
  }
}
'@
$Object1 = Invoke-RestMethod -Uri 'https://www.thorlabs.com/graphql' -Method Post -Body (@{ query = $Query } | ConvertTo-Json -Compress) -ContentType 'application/json'

$Query = @"
query {
  page(
    storeId: "Thorlabs-Website"
    id: "$($Object1.data.slugInfo.entityInfo.id)"
    cultureName: "en-US"
  ) {
    content
    permalink
  }
}
"@
$Object2 = Invoke-RestMethod -Uri 'https://www.thorlabs.com/graphql' -Method Post -Body (@{ query = $Query } | ConvertTo-Json -Compress) -ContentType 'application/json'
$Object3 = $Object2.data.page.content | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object3.tabs.Where({ $_.contentLink.expanded.name -eq 'Application' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'Elliptec 32-Bit Software for 32-Bit Windows' }, 'First')[0].contentLink.expanded[0].download.url.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
}
$VersionX86 = $Object3.tabs.Where({ $_.contentLink.expanded.name -eq 'Application' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'Elliptec 32-Bit Software for 32-Bit Windows' }, 'First')[0].contentLink.expanded[0].version

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object3.tabs.Where({ $_.contentLink.expanded.name -eq 'Application' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'Elliptec 64-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].download.url.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
}
$VersionX64 = $Object3.tabs.Where({ $_.contentLink.expanded.name -eq 'Application' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -eq 'Elliptec 64-Bit Software for 64-Bit Windows' }, 'First')[0].contentLink.expanded[0].version

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'Thorlabs ELLO.msi'
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
      # ProductCode
      $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries
      $Installer['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
        }
      )
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
