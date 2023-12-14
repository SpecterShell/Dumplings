$Object = Invoke-WebRequest -Uri 'http://www.bookxnote.com/' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('//*[@class="carousel-centered"]/div/p[2]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = $InstallerUrl1 = $Object.SelectSingleNode('//*[@class="carousel-centered"]/a[contains(./text(), "Win32")]').Attributes['href'].Value
  NestedInstallerFiles = @(
    @{
      RelativeFilePath = ([uri]$InstallerUrl1).Segments[-1] -creplace '\.zip$', '.exe'
    }
  )
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = $InstallerUrl2 = $Object.SelectSingleNode('//*[@class="carousel-centered"]/a[contains(./text(), "Win64")]').Attributes['href'].Value
  NestedInstallerFiles = @(
    @{
      RelativeFilePath = ([uri]$InstallerUrl2).Segments[-1] -creplace '\.zip$', '.exe'
    }
  )
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object.SelectSingleNode('//*[@class="carousel-centered"]/div/p[2]').InnerText,
  '(\d{4}年\d{1,2}月\d{1,2}日)'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
