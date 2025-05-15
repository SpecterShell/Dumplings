$Prefix = 'https://pan.sjtu.edu.cn/releases/'
$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $ReleaseNotes = [System.Text.StringBuilder]::new()
      if ($Object1.Contains('features') -and $Object1.features.Contains('en-US')) {
        $ReleaseNotes = $ReleaseNotes.AppendLine('功能更新：')
        $ReleaseNotes = $ReleaseNotes.AppendLine(($Object1.features.'en-US' | ConvertTo-UnorderedList))
      }
      if ($Object1.Contains('bugfixs') -and $Object1.bugfixs.Contains('en-US')) {
        $ReleaseNotes = $ReleaseNotes.AppendLine('功能修复：')
        $ReleaseNotes = $ReleaseNotes.AppendLine(($Object1.bugfixs.'en-US' | ConvertTo-UnorderedList))
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes.ToString() | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotes (zh-CN)
      $ReleaseNotesCN = [System.Text.StringBuilder]::new()
      if ($Object1.Contains('features') -and $Object1.features.Contains('zh-CN')) {
        $ReleaseNotesCN = $ReleaseNotesCN.AppendLine('功能更新：')
        $ReleaseNotesCN = $ReleaseNotesCN.AppendLine(($Object1.features.'zh-CN' | ConvertTo-UnorderedList))
      }
      if ($Object1.Contains('bugfixs') -and $Object1.bugfixs.Contains('zh-CN')) {
        $ReleaseNotesCN = $ReleaseNotesCN.AppendLine('功能修复：')
        $ReleaseNotesCN = $ReleaseNotesCN.AppendLine(($Object1.bugfixs.'zh-CN' | ConvertTo-UnorderedList))
      }
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
