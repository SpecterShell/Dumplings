$this.CurrentState = Invoke-WondershareXmlDownloadApi -ProductId 5373

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Version, '(\d+\.\d+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl           = 'https://download.edrawsoft.com/cbs_down/orgchartcreator_full5373.exe'
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName   = "OrgCharting $($this.CurrentState.Version)"
      Publisher     = 'EdrawSoft'
      ProductCode   = 'OrgCharting_is1'
      InstallerType = 'inno'
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
