$Object = Invoke-RestMethod -Uri 'https://meeting.kdocs.cn/api/v1/app/version?os=win&app=meeting&try_get_gray=true'

# Version
$this.CurrentState.Version = $Object.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data.market_url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object.data.updated_at | ConvertFrom-UnixTimeSeconds

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.data.content | ConvertTo-OrderedList | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $this.CurrentState.RealVersion = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
