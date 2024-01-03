$Object1 = Invoke-RestMethod -Uri 'https://www.axure.com/update-check/CheckForUpdate?info=%7B%22ClientVersion%22%3A%2210.0.0.0000%22%2C%22ClientOS%22%3A%22Windows%7C64bit%22%7D'

# Version
$Build = [regex]::Match($Object1, '(?m)^id=([\d]+)$').Groups[1].Value
$this.CurrentState.Version = '10.0.0.' + $Build

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://axure.cachefly.net/versions/10-0/AxureRP-Setup-${Build}.exe"
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [datetime]::ParseExact(
  [regex]::Match($Object1, '(?m)^subtitle=(\d{1,2}/\d{1,2}/\d{4})').Groups[1].Value,
  'M/d/yyyy',
  $null
).ToString('yyyy-MM-dd')

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = [regex]::Match($Object1, '(?s)message=(.+)').Groups[1].Value.Split('<title>').Where({ $_.Contains($this.CurrentState.Version) })[0] | Split-LineEndings | Select-Object -Skip 2 | Format-Text
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
