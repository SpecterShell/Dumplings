$Object1 = Invoke-RestMethod -Uri 'https://www.hellofont.cn/api/system/client-channel?platform=windows&channel=official'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.link | ConvertTo-UnescapedUri
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesObject = $null

      $Object2 = (Invoke-RestMethod -Uri 'https://www.hellofont.cn/api/system/client-version').Where({ $_.PlatformId -eq 0 }, 'First')[0]
      if ($Object2.Version -eq $this.CurrentState.Version) {
        $ReleaseNotesObject = $Object2
      } else {
        $Object3 = (Invoke-RestMethod -Uri 'https://back2.hellofont.cn/ziyou/ClientManagement/api/ClientVersion/HistoryClientVersionList' -Method Post -Body @{ PlatformId = '0' }).List.Where({ $_.Version -eq $this.CurrentState.Version }, 'First')
        if ($Object3) {
          $ReleaseNotesObject = $Object3[0]
        } else {
          $this.Log("No release notes for version $($this.CurrentState.Version)", 'Warning')
        }
      }

      if ($ReleaseNotesObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
          $ReleaseNotesObject.TimeStamp,
          'yyyyMMddHHmmssfff',
          $null
        ) | ConvertTo-UtcDateTime -Id 'China Standard Time'

        $ReleaseNotesList = @()
        if ($ReleaseNotesObject.News) {
          $ReleaseNotesList += '新增功能：'
          $ReleaseNotesList += $ReleaseNotesObject.News | ConvertTo-UnorderedList | Format-Text
        }
        if ($ReleaseNotesObject.Bugs) {
          $ReleaseNotesList += '问题修复：'
          $ReleaseNotesList += $ReleaseNotesObject.Bugs | ConvertTo-UnorderedList | Format-Text
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesList | Format-Text
        }
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
