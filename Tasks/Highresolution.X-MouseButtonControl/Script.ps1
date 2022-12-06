$Object = Invoke-WebRequest -Uri 'https://highrez.co.uk/downloads/xmbc_changelog.htm' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('/html/body/div[2]/b').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.highrez.co.uk/scripts/download.asp?package=XMouse'
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [datetime]::ParseExact(
  [regex]::Match(
    $Object.SelectSingleNode('/html/body/div[2]/text()').InnerText,
    '\((.+)\)'
  ).Groups[1].Value,
  # "[string[]]" is needed here to convert "array" object to string array
  [string[]]@(
    "d'st' MMMM yyyy",
    "d'nd' MMMM yyyy",
    "d'rd' MMMM yyyy",
    "d'th' MMMM yyyy"
  ),
  (Get-Culture -Name 'en-US'),
  [System.Globalization.DateTimeStyles]::None
)

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object.SelectNodes('/html/body/ul[1]/li').InnerText.Replace("`t", ' ') | Format-Text | ConvertTo-UnorderedList
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
