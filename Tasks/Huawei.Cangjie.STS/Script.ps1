$Filename = $Global:DumplingsStorage.CangjieSTSPage.SelectSingleNode("//div[contains(@class, 'ivu-col') and contains(text(), '.exe') and not(contains(text(), 'android')) and not(contains(text(), 'ohos'))]").InnerText.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Global:DumplingsStorage.CangjieSTSPrefix ([regex]::Match($Global:DumplingsStorage.CangjieVersionJS, "url:`"([^`"]+$([regex]::Escape($Filename))[^`"]+?)`"").Groups[1].Value)
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Global:DumplingsStorage.CangjieSTSPage.SelectSingleNode('//div[@class="subpage-content-time"]').InnerText, '(20\d{2}/\d{1,2}/\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $null
      }

      $ReleaseNotesUrl = "https://cj-docs.gitcode.com/zh/$($this.CurrentState.Version)/release-notes/cangjie-$($this.CurrentState.Version)-release-notes.html"
      $Object1 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
      }

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.SelectSingleNode('//main') | Get-TextContent | Format-Text
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
