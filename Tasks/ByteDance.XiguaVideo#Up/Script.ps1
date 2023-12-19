$Object = Invoke-RestMethod -Uri 'https://tron.jiyunhudong.com/api/sdk/check_update?pid=6922326164589517070&branch=master&buildId=&uid='

# Version
$this.CurrentState.Version = $Object.data.manifest.win32.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.data.manifest.win32.urls
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object.data.manifest.win32.extra.uploadDate | ConvertFrom-UnixTimeMilliseconds

# ReleaseNotes (zh-CN)
# $this.CurrentState.Locale += [ordered]@{
#   Locale = 'zh-CN'
#   Key    = 'ReleaseNotes'
#   Value  = $Object.data.releaseNote | Format-Text
# }

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
}
