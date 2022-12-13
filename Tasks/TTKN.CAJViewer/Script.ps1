$Object = (Invoke-WebRequest -Uri 'https://cajviewer.cnki.net/download.html' | ConvertFrom-Html).SelectNodes(
  '/html/body/div[2]/div/div/div[contains(div[1]/div[2]/text(), "CAJViewer 7.3") and not(contains(div[1]/div[2]/text(), "精简版"))]'
)

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('div[1]/div[2]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# RealVersion
$Task.CurrentState.RealVersion = [regex]::Match(
  $Task.CurrentState.Version,
  '(\d+\.\d+\.\d)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.SelectSingleNode('div[5]/a').Attributes['href'].Value | ConvertTo-UnescapedUri
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object.SelectSingleNode('div[4]/div').InnerText,
  '(\d{4}-\d{1,2}-\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
