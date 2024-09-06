$Prefix = 'https://cdimage.deepin.com/applications/deepin-cloud-scan/'

$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Prefix + $Object1.Links.Where({ (Get-Member -Name 'href' -InputObject $_ -ErrorAction SilentlyContinue) -and $_.href.EndsWith('.exe') })[0].href
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $InstallerUrl + '?l=zh-CN'
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

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
