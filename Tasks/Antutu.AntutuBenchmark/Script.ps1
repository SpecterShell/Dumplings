$Object = Invoke-WebRequest -Uri 'https://www.antutu.com/' | ConvertFrom-Html

$Node = $Object.SelectNodes('//*[@class="download" and contains(./div/h4/text()[1], "安兔兔评测") and contains(./div/h4/span, "Win")]')

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Node.SelectSingleNode('./div/p/text()').InnerText,
  'v([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Node.SelectSingleNode('./div/a').Attributes['href'].Value
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = ($Node.SelectSingleNode('./div/p/span').InnerText | ConvertTo-HtmlDecodedText).Trim() | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
