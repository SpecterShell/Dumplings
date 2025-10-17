$Object1 = Invoke-RestMethod -Uri 'https://api.viewdepth.cn/app_info' -Body @{
  app_id      = 'pixpin'
  # Switch to value 1 here for beta releases.
  update_type = '1'
  sys         = 'win'
  ver         = $this.Status.Contains('New') ? '1.9.11.8' : $this.LastState.Version
}

# Version
$this.CurrentState.Version = $Object1.ver_info.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.ver_info.direct_url[0] -replace 'true|false'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ver_info.created_at.ToUniversalTime()

      # ReleaseNotes (en-US)
      $ReleaseNotesObject = $Object1.ver_info.desc | Convert-MarkdownToHtml
      $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("./h2[text()='$($this.CurrentState.Version.Split('.')[0..2] -join '.')']")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
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
          Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
        }
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.ver_info.desc_url
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
