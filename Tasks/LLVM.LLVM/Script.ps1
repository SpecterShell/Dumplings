$RepoOwner = 'llvm'
$RepoName = 'llvm-project'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^llvmorg-'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('win32') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('win64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
if ($Asset = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('woa64') }, 'First')) {
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'arm64'
    InstallerUrl = $Asset[0].browser_download_url | ConvertTo-UnescapedUri
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.html_url
      }

      $Object2 = Invoke-WebRequest -Uri 'https://llvm.org/header.incl' | ConvertFrom-Html

      $ReleaseNotesUrlNode = $Object2.SelectSingleNode("/html/body/table/tr/td[1]/div[5]/span/text()[contains(string(), '$($this.CurrentState.Version)')]/following-sibling::a[1]")
      if ($ReleaseNotesUrlNode) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl = $ReleaseNotesUrlNode.Attributes['href'].Value
        }

        $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

        $ReleaseNotesTitleNode = $Object3.SelectSingleNode('//div[@id="post_1"]/div[@class="post"]/h1[contains(text(), "Changes") or contains(text(), "Release Notes")]')
        if ($ReleaseNotesTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h1'; $Node = $Node.NextSibling) { $Node }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotesUrl (en-US) and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  { $_.Contains('Changed') -and -not $_.Contains('Updated') } {
    $this.Config.IgnorePRCheck = $true
  }
  'Changed|Updated' {
    $this.Message()
    $this.Submit()
  }
}
