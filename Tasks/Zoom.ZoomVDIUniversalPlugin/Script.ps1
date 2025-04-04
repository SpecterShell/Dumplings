$Object1 = Invoke-WebRequest -Uri 'https://zoom.us/product/version' -UserAgent 'Mozilla/5.0 (ZOOM.Win 10.0 x64)' -Body @{
  productName = 'vdi'
  platform    = 'Universal'
  os          = 'Win32'
  pluginOS    = 'win'
  cv          = $this.Status.Contains('New') ? '6.3.10' : ($this.LastState.Version.Split('.')[0..2] -join '.')
} | ConvertFrom-ProtoBuf
$Object2 = $Object1['12'] | ConvertFrom-Json

# Version
$this.CurrentState.Version = [regex]::Match($Object2.x64.url, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[@(0, 1, 3)] -join '.'

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x86'
#   InstallerUrl = Join-Uri 'https://zoom.us/' $Object2.url
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri 'https://zoom.us/' $Object2.x64.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri 'https://zoom.us/' $Object2.arm64.url
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
