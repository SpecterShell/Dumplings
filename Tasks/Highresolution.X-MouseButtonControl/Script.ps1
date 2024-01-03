$Object1 = Invoke-WebRequest -Uri 'https://highrez.co.uk/downloads/xmbc_changelog.htm' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/div[2]/div/b').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.highrez.co.uk/scripts/download.asp?package=XMouse'
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact(
  [regex]::Match(
    $Object1.SelectSingleNode('/html/body/div[2]/div/text()').InnerText,
    '\((.+)\)'
  ).Groups[1].Value,
  # "[string[]]" is needed here to convert "array" object to string array
  [string[]]@(
    "d'st' MMM yyyy", "d'st' MMMM yyyy",
    "d'nd' MMM yyyy", "d'nd' MMMM yyyy",
    "d'rd' MMM yyyy", "d'rd' MMMM yyyy",
    "d'th' MMM yyyy", "d'th' MMMM yyyy"
  ),
  (Get-Culture -Name 'en-US'),
  [System.Globalization.DateTimeStyles]::None
).ToString('yyyy-MM-dd')

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = ($Object1.SelectNodes('/html/body/div[2]/div/following-sibling::*') | Get-TextContent | Format-Text).Replace("`t", ' ')
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
