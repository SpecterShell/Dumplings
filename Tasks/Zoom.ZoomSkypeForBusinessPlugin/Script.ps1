$Object1 = Invoke-WebRequest -Uri 'https://zoom.us/product/version' -Method Post -UserAgent 'Mozilla/5.0 (ZOOM.Win 10.0 x64)' -Headers @{ 'ZM-CAP' = '8300567970761955255,6445493618999263204' } -Form @{
  productName = 'lyncplugin'
  cv          = $this.LastState.Contains('Version') ? $this.LastState.Version : '5.13.10'
} | ConvertFrom-ProtoBuf

# Version
$this.CurrentState.Version = $Object1.'10'

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://zoom.us/client/$($this.CurrentState.Version)/ZoomLyncPluginSetup.msi"
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
