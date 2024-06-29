# x64
$Object1 = Invoke-RestMethod -Uri 'https://www.focusky.com.cn/update/focusky-update-info.php?digit=64'

# x86
$Object2 = Invoke-RestMethod -Uri 'https://www.focusky.com.cn/update/focusky-update-info.php?digit=32'

if ($Object1.CurrentVersionNumber -ne $Object2.CurrentVersionNumber) {
  $this.Log("x86 version: $($Object2.CurrentVersionNumber)")
  $this.Log("x64 version: $($Object1.CurrentVersionNumber)")
  throw 'Distinct versions detected'
}

# Version
$this.CurrentState.Version = $Object1.CurrentVersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.FileURL
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.FileURL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-RestMethod -Uri 'https://www.animiz.cn/webapis/appupdate/history' -Method Post -Body (@{
          'app' = 'focusky'
          'os'  = 'win'
        } | ConvertTo-Json -Compress
      ) -ContentType 'application/json; charset=UTF-8'

      $ReleaseNotesNode = $Object3.data.list.Where({ $_.version -eq $this.CurrentState.Version }, 'First')
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesNode[0].date | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode[0].new | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
