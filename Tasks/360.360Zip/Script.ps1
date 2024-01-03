$Object1 = Invoke-WebRequest -Uri 'https://www.360totalsecurity.com/en/360zip/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="primary-actions"]/p/span').InnerText,
  '(\d+\.\d+\.\d+\.\d+)'
).Groups[1].Value

$Object2 = Invoke-WebRequest -Uri 'https://www.360totalsecurity.com/en/download-free-360-zip/' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https:' + $Object2.SelectSingleNode('//*[@id="download-intro"]/div[1]/a').Attributes['href'].Value
}

if ($LocalStorage.Contains('360Zip') -and $LocalStorage['360Zip'].Contains($Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $LocalStorage['360Zip'].$Version.ReleaseTime

  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage['360Zip'].$Version.ReleaseNotesCN
  }
} else {
  $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
