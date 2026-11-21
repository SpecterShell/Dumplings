$Release = Invoke-GitHubApi -Uri 'https://api.github.com/repos/LingyiChen-AI/JadeAI/releases/latest'

# Version
$this.CurrentState.Version = $Release.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Release.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match 'win' -and $_.name -match 'Setup' }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Release.published_at.ToUniversalTime()

      # if (-not [string]::IsNullOrWhiteSpace($Release.body)) {
      #   $ReleaseNotesObject = $Release.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
      #   $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not ($Node.Name -eq 'h2' -and $Node.InnerText.Contains('Downloads')); $Node = $Node.NextSibling) { $Node }
      #   # ReleaseNotes (en-US)
      #   $this.CurrentState.Locale += [ordered]@{
      #     Locale = 'en-US'
      #     Key    = 'ReleaseNotes'
      #     Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
      #   }
      # } else {
      #   $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      # }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Release.html_url
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
