$Object1 = Invoke-RestMethod -Uri 'https://hub.deepcool.com/official/software/official/download-path?version=latest&name=deep-creative'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.content.external
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object1.data.content.internal
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://hub.deepcool.com/official/software/official/software-info-list?name=deep-creative').data.content.Where({ $_.version -eq $this.CurrentState.Version }, 'First')[0]

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.buildTime | Get-Date -Format 'yyyy-MM-dd'

      $ReleaseNotes = [System.Text.StringBuilder]::new()
      if ($Object2.updateLog.en_us.fix.Count -gt 0) {
        $null = $ReleaseNotes.AppendLine('fix:').AppendLine(($Object2.updateLog.en_us.fix | ConvertTo-UnorderedList))
      }
      if ($Object2.updateLog.en_us.feat.Count -gt 0) {
        $null = $ReleaseNotes.AppendLine('feat:').AppendLine(($Object2.updateLog.en_us.feat | ConvertTo-UnorderedList))
      }
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes.ToString() | Format-Text
      }

      $ReleaseNotesCN = [System.Text.StringBuilder]::new()
      if ($Object2.updateLog.zh_cn.fix.Count -gt 0) {
        $null = $ReleaseNotesCN.AppendLine('fix:').AppendLine(($Object2.updateLog.zh_cn.fix | ConvertTo-UnorderedList))
      }
      if ($Object2.updateLog.zh_cn.feat.Count -gt 0) {
        $null = $ReleaseNotesCN.AppendLine('feat:').AppendLine(($Object2.updateLog.zh_cn.feat | ConvertTo-UnorderedList))
      }
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesCN.ToString() | Format-Text
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
