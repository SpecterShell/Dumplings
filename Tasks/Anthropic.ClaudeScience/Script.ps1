$Object1 = Invoke-RestMethod -Uri 'https://downloads.claude.ai/claude-science/latest/manifest.json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  InstallerType   = 'exe'
  InstallerUrl    = "https://downloads.claude.ai/claude-science/$($this.CurrentState.Version)/windows-x64.exe"
  InstallerSha256 = $Object1.sha256.'windows-x64'.ToUpper()
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'arm64'
  InstallerType   = 'exe'
  InstallerUrl    = "https://downloads.claude.ai/claude-science/$($this.CurrentState.Version)/windows-arm64.exe"
  InstallerSha256 = $Object1.sha256.'windows-arm64'.ToUpper()
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.buildDate.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri 'https://claude.com/docs/claude-science/changelog.md' | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis'
      $ReleaseNotesTitleNode = $Object2.SelectNodes('//p/strong') | Where-Object -FilterScript { $_.InnerText.Trim() -eq $this.CurrentState.Version } | Select-Object -First 1
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = [System.Collections.Generic.List[object]]::new()
        for ($Node = $ReleaseNotesTitleNode.ParentNode.NextSibling; $Node; $Node = $Node.NextSibling) {
          if ($Node.Name -eq 'p' -and $Node.SelectSingleNode('./strong') -and $Node.SelectSingleNode('./strong').InnerText -match '^\d+\.\d+\.\d+$') { break }
          if ($Node.Name -eq 'p' -and $Node.InnerText -match '^\s*[A-Z][a-z]+ \d{1,2}, \d{4}\s*$') { continue }
          $ReleaseNotesNodes.Add($Node)
        }

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
