$Object1 = Invoke-RestMethod -Uri "https://upgrade.pixpin.cn/api/check/0/$($this.Status.Contains('New') ? '3.3.5.7' : $this.LastState.Version)/windows/x64/cn/zh-cn/.exe"

if ($Object1.Count -eq 0) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1[0].direct_url.Where({ $_ -match 'download.pixpinapp.com' }, 'First')[0]
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x64'
  InstallerUrl    = $Object1[0].direct_url.Where({ $_ -match 'down.pixpin.cn' }, 'First')[0]
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1[0].created_at | Get-Date | ConvertTo-UtcDateTime -Id 'UTC'

      # ReleaseNotes (zh-CN)
      $ReleaseNotesObject = $Object1[0].desc | Convert-MarkdownToHtml
      $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("./h2[contains(text(), '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
        }
      }

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1[0].desc_url
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri "https://upgrade.pixpin.cn/api/check/1/$($this.Status.Contains('New') ? '3.3.5.7' : $this.LastState.Version)/windows/x64/cn/en-us/.exe"

      if ($Object2[0].version -eq $this.CurrentState.Version) {
        # ReleaseNotes (en-US)
        $ReleaseNotesENObject = $Object2[0].desc | Convert-MarkdownToHtml
        $ReleaseNotesENTitleNode = $ReleaseNotesENObject.SelectSingleNode("./h2[contains(text(), '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
        if ($ReleaseNotesENTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesENTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesENObject | Get-TextContent | Format-Text
          }
        }

        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $Object2[0].desc_url
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
