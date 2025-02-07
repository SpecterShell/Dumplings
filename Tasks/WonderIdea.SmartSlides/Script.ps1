# x86
$Object1 = Invoke-RestMethod -Uri 'https://www.animiz.cn/webapis/appupdate/client-latest?app=smartslides&digit=32'

# x64
$Object2 = Invoke-RestMethod -Uri 'https://www.animiz.cn/webapis/appupdate/client-latest?app=smartslides&digit=64'

if ($Object1.data.CurrentVersionNumber -ne $Object2.data.CurrentVersionNumber) {
  $this.Log("x86 version: $($Object1.data.CurrentVersionNumber)")
  $this.Log("x64 version: $($Object2.data.CurrentVersionNumber)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.data.CurrentVersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.data.FileURL.Replace('files.animiz.cn', 'files.focusky.com.cn') | ConvertTo-Https
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.data.FileURL.Replace('files.animiz.cn', 'files.focusky.com.cn') | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-RestMethod -Uri 'https://www.animiz.cn/webapis/appupdate/history?app=smartslides&os=win'

      $ReleaseNotesObject = $Object3.data.list.Where({ $_.version -eq $this.CurrentState.Version }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesObject[0].date | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotes = [System.Text.StringBuilder]::new()
        if ($ReleaseNotesObject[0].new) {
          $ReleaseNotes = $ReleaseNotes.AppendLine('新增')
          $ReleaseNotes = $ReleaseNotes.AppendLine(($ReleaseNotesObject.new.Split('##') | ConvertTo-OrderedList))
        }
        if ($ReleaseNotesObject[0].fix) {
          $ReleaseNotes = $ReleaseNotes.AppendLine('修复')
          $ReleaseNotes = $ReleaseNotes.AppendLine(($ReleaseNotesObject.fix.Split('##') | ConvertTo-OrderedList))
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotes.ToString() | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
