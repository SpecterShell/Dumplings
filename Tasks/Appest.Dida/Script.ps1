$Object = Invoke-WebRequest -Uri 'https://pull.dida365.com/windows/release_note.json' | Read-ResponseContent | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.dida365.com/static/getApp/download?type=win'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.dida365.com/static/getApp/download?type=win64'
}

# Sometimes the installers do not match the version
if ($this.CurrentState.Installer[0].InstallerUrl.Contains($this.CurrentState.Version -csplit '\.' -join '')) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object.release_date, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')

  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = ($Object.data | Where-Object -Property 'lang' -EQ -Value 'en').content | Format-Text
  }
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = ($Object.data | Where-Object -Property 'lang' -EQ -Value 'zh_cn').content | Format-Text
  }
} else {
  $this.Logging('The installers do not match the version', 'Warning')

  # Version
  $this.CurrentState.Version = [regex]::Match(
    $this.CurrentState.Installer[0].InstallerUrl,
    '([\d\.]+)\.exe'
  ).Groups[1].Value -creplace '(?<=\d)(\d)', '.$1'
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
