$Object1 = Invoke-RestMethod -Uri 'https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/VERSION'

# Version
$this.CurrentState.Version = $Object1.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/$($this.CurrentState.Version)/windows_amd64/AmazonSSMAgentSetup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $RepoOwner = 'aws'
      $RepoName = 'amazon-ssm-agent'

      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/tags/$($this.CurrentState.Version)"

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object2.body)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object2.html_url
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
