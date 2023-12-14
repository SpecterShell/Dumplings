$Prefix = 'http://plorkyeran.com/aegisub/'

$Object = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html

$ReleaseNotesTitle = $Object.SelectSingleNode('/html/body/h3[1]').InnerText

# Version
$Task.CurrentState.Version = [regex]::Match($ReleaseNotesTitle, '(r[\d]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix + $Object.SelectSingleNode('/html/body/div[1]/a[1]').Attributes['href'].Value
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix + $Object.SelectSingleNode('/html/body/div[2]/a[1]').Attributes['href'].Value
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [datetime]::ParseExact(
  [regex]::Match($ReleaseNotesTitle, '(\d{2}/\d{2}/\d{2})').Groups[1].Value,
  'MM/dd/yy',
  $null
).ToString('yyyy-MM-dd')

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object.SelectSingleNode('/html/body/ul[2]') | Get-TextContent | Format-Text
}

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
