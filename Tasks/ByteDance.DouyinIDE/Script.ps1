$Object1 = Invoke-RestMethod -Uri 'https://tron.jiyunhudong.com/api/sdk/check_update?pid=6898629266087352589&branch=master&buildId=&uid='

# Version
$this.CurrentState.Version = $Object1.data.manifest.win32.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.manifest.win32.urls[0]
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.releaseNote | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri 'https://developer.open-douyin.com/docs/resource/zh-CN/mini-app/develop/dev-tools/developer-instrument/download/developer-instrument-update-and-download?__loader=zh-CN%2F%24&__ssrDirect=true'
      $Object3 = [Newtonsoft.Json.Linq.JObject]::Parse($Object2.data.content)

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object3.SelectToken("$..[?(@.insert =~ /^$($this.CurrentState.Version)/)]"), '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
