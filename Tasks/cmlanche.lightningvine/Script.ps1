$Object1 = (Invoke-RestMethod -Uri 'https://sdt.zishu.life/appcast.xml').Where({ $_.enclosure.url.EndsWith('.exe') }, 'First')[0]

# Version
$this.CurrentState.Version = $Object1.enclosure.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.enclosure.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = 'https://lightningvine.zishu.life/history.html'
      }

      $Object2 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/cmlanche/lightningvine-docs/refs/heads/main/docs/history.md' | Convert-MarkdownToHtml

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h2[contains(.//text(), '$($this.CurrentState.Version.Split('+')[0])')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{4}/\d{1,2}/\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
          if (-not $Node.InnerText.Contains('常见问题') -and -not $Node.InnerText.Contains('特别说明') -and -not $Node.InnerText.Contains('下载地址')) {
            $Node
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl + '#_' + ($ReleaseNotesTitleNode.InnerText -creplace '\W+', '-')
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
