$Object1 = Invoke-RestMethod -Uri 'https://jprx.m.qq.com/data/4066/forward' -Method POST -Body '{"system_type":"win"}' -ContentType 'application/json'

# Version
$this.CurrentState.Version = $Object1.data.resp.data.version_code

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.resp.data.download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.resp.data.update_content
      }
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
