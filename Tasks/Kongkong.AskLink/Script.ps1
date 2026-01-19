$Object1 = (Invoke-RestMethod -Uri 'https://api.asklink.com/download/list').data.Where({ $_.clientType -eq 'WIN' }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($Object1.name, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.url | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = $Object1.remark | ConvertFrom-Json

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2.zh_CN | Format-Text
      }

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.en | Format-Text
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
