$Object1 = Invoke-WebRequest -Uri 'https://store.wiris.com/en/products/mathtype/download/windows' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en'
  InstallerUrl    = $InstallerUrl = $Object1.SelectSingleNode('//*[@id="mt_en_open_modal"]').Attributes['data-content'].Value
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'de'
  InstallerUrl    = $InstallerUrl -replace '-en-', '-de-'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'fr'
  InstallerUrl    = $InstallerUrl -replace '-en-', '-fr-'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ja'
  InstallerUrl    = $InstallerUrl -replace '-en-', '-jp-'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-Hans'
  InstallerUrl    = $InstallerUrl -replace '-en-', '-zh-'
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

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
