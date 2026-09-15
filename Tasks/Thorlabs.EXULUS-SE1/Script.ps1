$Query = @'
query {
  slugInfo(
    slug: "software-pages/EXULUS"
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

# Version
$this.CurrentState.Version = $Object3.tabs.Where({ $_.contentLink.expanded.name -eq 'Archive' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -match 'EXULUS-SE1' }, 'First')[0].contentLink.expanded[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $InstallerUrl = $Object3.tabs.Where({ $_.contentLink.expanded.name -eq 'Archive' }, 'First')[0].contentLink.expanded.sections.Where({ $_.contentLink.expanded.name -match 'EXULUS-SE1' }, 'First')[0].contentLink.expanded[0].download.url.Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "$($InstallerUrl | Split-Path -LeafBase).exe"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
