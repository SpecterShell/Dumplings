# The downloads metadata is the publisher's own release feed, declared with its download hosts in
# https://vibe42.ai/install.md. The endpoint sits behind a bot filter that serves an all-null payload
# to non-browser clients, so request it with a browser User-Agent.
$Object1 = Invoke-RestMethod -Uri 'https://vibe42.ai/downloads/api/meta' -UserAgent $DumplingsBrowserUserAgent

# Version
$this.CurrentState.Version = [string]$Object1.windowsX86_64.version

# Installer
# windowsX86_64 is the only native Windows entry; Windows on Arm64 is still marked coming soon.
$InstallerUrl = [string]$Object1.windowsX86_64.url
$InstallerSha256 = [string]$Object1.windowsX86_64.sha256
if ([string]::IsNullOrWhiteSpace($InstallerUrl) -or [string]::IsNullOrWhiteSpace($InstallerSha256)) {
  throw 'The downloads metadata does not publish a native Windows x64 installer.'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  InstallerType   = 'nullsoft'
  InstallerUrl    = $InstallerUrl
  InstallerSha256 = $InstallerSha256.ToUpperInvariant()
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # The feed carries no date, so ReleaseTime is left to the framework's installer Last-Modified fallback.

    try {
      # ReleaseNotes (en-US) and ReleaseNotesUrl (en-US)
      # The changelog groups entries by minor version, so the selected section covers the whole line.
      $MinorVersion = [regex]::Match($this.CurrentState.Version, '^[0-9]+\.[0-9]+').Value
      $Html = (Invoke-RestMethod -Uri 'https://vibe42.ai/changelog.md' -UserAgent $DumplingsBrowserUserAgent) | Convert-MarkdownToHtml
      $ReleaseNotesTitleNode = $Html.SelectSingleNode("//h2[normalize-space() = '$MinorVersion']")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://vibe42.ai/changelog#' + ($MinorVersion -replace '\.', '')
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotes (zh-CN) and ReleaseNotesUrl (zh-CN)
      $MinorVersion = [regex]::Match($this.CurrentState.Version, '^[0-9]+\.[0-9]+').Value
      $Html = (Invoke-RestMethod -Uri 'https://vibe42.ai/zh-HANS/changelog.md' -UserAgent $DumplingsBrowserUserAgent) | Convert-MarkdownToHtml
      $ReleaseNotesTitleNode = $Html.SelectSingleNode("//h2[normalize-space() = '$MinorVersion']")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotesUrl'
          Value  = 'https://vibe42.ai/zh-HANS/changelog#' + ($MinorVersion -replace '\.', '')
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
