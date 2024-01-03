$this.CurrentState = Invoke-WondershareXmlDownloadApi -ProductId 5372

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl           = 'https://download.edrawsoft.com/cbs_down/edrawproject_full5372.exe'
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName   = "Wondershare EdrawProj $($this.CurrentState.Version.Split('.')[0..1] -join '.')"
      Publisher     = 'EdrawSoft'
      ProductCode   = 'Wondershare EdrawProj_is1'
      InstallerType = 'inno'
    }
  )
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
