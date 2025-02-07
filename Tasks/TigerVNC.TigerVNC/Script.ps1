$ProjectName = 'tigervnc'
$RootPath = '/stable'

$Object1 = Invoke-RestMethod -Uri "https://sourceforge.net/projects/${ProjectName}/rss?path=${RootPath}"
$Assets = $Object1.Where({ $_.title.'#cdata-section' -match "^$([regex]::Escape($RootPath))/[\d\.]+/tigervnc(?:64)?-\d+(?:\.\d+)+\.exe$" })

# Version
$this.CurrentState.Version = [regex]::Match($Assets[0].title.'#cdata-section', "^$([regex]::Escape($RootPath))/([\d\.]+)/").Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Assets.Where({ $_.title.'#cdata-section'.Contains('tigervnc-') }, 'First')[0].link | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Assets.Where({ $_.title.'#cdata-section'.Contains('tigervnc64-') }, 'First')[0].link | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $Assets.Where({ $_.title.'#cdata-section'.Contains('tigervnc64-') }, 'First')[0].pubDate,
        'ddd, dd MMM yyyy HH:mm:ss "UT"',
        (Get-Culture -Name 'en-US')
      ) | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }

      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/TigerVNC/tigervnc/releases/tags/v$($this.CurrentState.Version)"

      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= $Object2.published_at.ToUniversalTime()

        if (-not [string]::IsNullOrWhiteSpace($Object2.body)) {
          $ReleaseNotesObject = $Object2.body | Convert-MarkdownToHtml -Extensions $MarkdigSoftlineBreakAsHardlineExtension
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not $Node.InnerText.Contains('Binaries are available from SourceForge'); $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object2.html_url
        }
      } else {
        $this.Log("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
