$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/TortoTech/torto/releases/latest'

# Version
$this.CurrentState.Version = $Version = $Object1.tag_name -replace '^v'

# WiX MSI with AllUsers=1, so the package is machine scope. The release also ships the portable ZIP
# and the macOS and Android artifacts, each with a .sha256 sibling except the MSI; only the MSI is
# packaged.
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  Scope         = 'machine'
  InstallerUrl  = $Object1.assets.Where({ $_.name -eq "Torto-${Version}-x86_64.msi" }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
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
      $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
      # The English change list is the body itself; the Chinese one is folded into a trailing
      # details block, so the English walk stops at that block.
      $DetailsNode = $ReleaseNotesObject.SelectSingleNode('./details')
      $Skip = $false
      $SkippedHeadingLevel = 0
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and $Node -ne $DetailsNode; $Node = $Node.NextSibling) {
        if ($Node.Name -match '^h([1-6])$') {
          $HeadingLevel = [int]$Matches[1]
          if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
            $Skip = $Node.InnerText -match '^\s*(Download|Downloads|Checksum|Hash|SHA-256)\s*$'
            if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
          }
        }
        if (-not $Skip -and $Node.Name -ne '#text') { $Node }
      }

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.html_url
      }

      if ($DetailsNode) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $DetailsNode | Get-TextContent | Format-Text
        }
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
