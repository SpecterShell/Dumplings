# x86
$Object1 = Invoke-RestMethod -Uri 'https://drawingmaster.wmindmap.cn/download/client-update?digit=32'

# x64
$Object2 = Invoke-RestMethod -Uri 'https://drawingmaster.wmindmap.cn/download/client-update?digit=64'

if ($Object1.CurrentVersionNumber -ne $Object2.CurrentVersionNumber) {
  $this.Log("x86 version: $($Object1.CurrentVersionNumber)")
  $this.Log("x64 version: $($Object2.CurrentVersionNumber)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.CurrentVersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.FileURL | ConvertTo-Https
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.FileURL | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-RestMethod -Uri 'https://drawingmaster.wmindmap.cn/webapis/appupdate/history?app=drawingmaster'

      $ReleaseNotesObject = $Object3.data.list.Where({ $_.version -eq $this.CurrentState.Version }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesObject[0].date | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotes = [System.Text.StringBuilder]::new()
        if ($ReleaseNotesObject[0].new) {
          $ReleaseNotes = $ReleaseNotes.AppendLine('新增功能')
          $ReleaseNotes = $ReleaseNotes.AppendLine(($ReleaseNotesObject[0].new | ConvertTo-OrderedList))
        }
        if ($ReleaseNotesObject[0].fix) {
          $ReleaseNotes = $ReleaseNotes.AppendLine('修复 bug')
          $ReleaseNotes = $ReleaseNotes.AppendLine(($ReleaseNotesObject[0].fix | ConvertTo-OrderedList))
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotes.ToString() | Format-Text
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
