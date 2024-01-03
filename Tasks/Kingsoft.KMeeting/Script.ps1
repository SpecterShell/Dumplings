$Object1 = Invoke-RestMethod -Uri 'https://meeting.kdocs.cn/api/v1/app/version?os=win&app=meeting&try_get_gray=true'

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = $Object1.data.market_url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.data.updated_at | ConvertFrom-UnixTimeSeconds

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.content | ConvertTo-OrderedList | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
