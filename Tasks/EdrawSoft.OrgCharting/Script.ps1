$Object1 = Invoke-RestMethod -Uri 'http://platform.wondershare.com/rest/v2/downloader/runtime/?product_id=5373&wae='

# Version
$this.CurrentState.Version = $Object1.wsrp.downloader.runtime.version.'#cdata-section'.Split('.')[0..1] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl           = $Object1.wsrp.downloader.runtime.download_url.'#cdata-section' | ConvertTo-Https
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
