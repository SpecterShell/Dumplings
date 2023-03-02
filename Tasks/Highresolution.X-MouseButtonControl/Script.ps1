$Object = Invoke-WebRequest -Uri 'https://highrez.co.uk/downloads/xmbc_changelog.htm' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('/html/body/div[2]/div/b').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.highrez.co.uk/scripts/download.asp?package=XMouse'
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [datetime]::ParseExact(
  [regex]::Match(
    $Object.SelectSingleNode('/html/body/div[2]/div/text()').InnerText,
    '\((.+)\)'
  ).Groups[1].Value,
  # "[string[]]" is needed here to convert "array" object to string array
  [string[]]@(
    "d'st' MMM yyyy",
    "d'nd' MMM yyyy",
    "d'rd' MMM yyyy",
    "d'th' MMM yyyy"
  ),
  (Get-Culture -Name 'en-US'),
  [System.Globalization.DateTimeStyles]::None
).ToString('yyyy-MM-dd')

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = ($Object.SelectNodes('/html/body/div[2]/div/following-sibling::*') | Get-TextContent | Format-Text).Replace("`t", ' ')
}

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
