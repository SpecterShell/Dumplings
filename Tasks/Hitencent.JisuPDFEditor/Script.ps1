$Object1 = Invoke-WebRequest -Uri 'https://www.jisupdfeditor.com/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="banner"]/div/div[2]/ul/li[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = [regex]::Match($this.CurrentState.Version, '(\d+\.\d+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="banner"]/div/div[2]/a').Attributes['href'].Value
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="banner"]/div/div[2]/ul/li[2]').InnerText,
  '(\d{4}-\d{1,2}-\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
