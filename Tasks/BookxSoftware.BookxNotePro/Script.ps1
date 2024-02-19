$Object1 = Invoke-WebRequest -Uri 'http://www.bookxnote.com/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@class="carousel-centered"]/div/p[2]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = $InstallerUrl1 = $Object1.SelectSingleNode('//*[@class="carousel-centered"]/a[contains(./text(), "Win32")]').Attributes['href'].Value
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = (Split-Path -Path $InstallerUrl1 -Leaf) -creplace '\.zip$', '.exe'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = $InstallerUrl2 = $Object1.SelectSingleNode('//*[@class="carousel-centered"]/a[contains(./text(), "Win64")]').Attributes['href'].Value
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = (Split-Path -Path $InstallerUrl2 -Leaf) -creplace '\.zip$', '.exe'
    }
  )
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match(
  $Object1.SelectSingleNode('//*[@class="carousel-centered"]/div/p[2]').InnerText,
  '(\d{4}年\d{1,2}月\d{1,2}日)'
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
