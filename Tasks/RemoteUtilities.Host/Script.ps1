$Object1 = Invoke-RestMethod -Uri 'https://update.remoteutilities.net/upgrade.ini' | ConvertFrom-Ini

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.general.host_url | ConvertTo-Https
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.remoteutilities.com/product/release-notes.php' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(text(), 'Remote Utilities $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) {
          if ($Node.InnerText -match 'Released on ([a-zA-Z]+\W+\d{1,2}\W+20\d{2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
          } elseif (-not $Node.InnerText.Contains('Platform')) {
            $Node
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.remoteutilities.com/zh-Hans/product/release-notes.php' | ConvertFrom-Html

      $ReleaseNotesCNTitleNode = $Object3.SelectSingleNode("//h2[contains(text(), 'Remote Utilities $($this.CurrentState.Version)')]")
      if ($ReleaseNotesCNTitleNode) {
        $ReleaseNotesCNNodes = for ($Node = $ReleaseNotesCNTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) {
          if ($Node.InnerText -match '发布日期 (20\d{2}年\d{1,2}月\d{1,2}日)') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime ??= $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
          } elseif (-not $Node.InnerText.Contains('平台：')) {
            $Node
          }
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNodes | Get-TextContent | Format-Text
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
