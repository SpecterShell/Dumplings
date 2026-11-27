$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/martianacademy/olympus-coder/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
  throw 'The latest release tag does not provide a numeric version.'
}

# Installer
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match 'Setup' -and $_.name -notmatch 'portable|update|BlockMap' }, 'First')[0]
if (-not $Asset) {
  throw 'The latest release does not provide a Windows NSIS setup installer.'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Asset.browser_download_url | ConvertTo-UnescapedUri
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

    $InstallerUrl = [string]$this.CurrentState.Installer[0].InstallerUrl
    $this.InstallerFiles[$InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerUrl

    $ChecksumAsset = $Object1.assets.Where({ $_.name -eq 'SHA256SUMS.txt' }, 'First')[0]
    if (-not $ChecksumAsset) {
      throw 'The latest release does not provide SHA256SUMS.txt to verify the installer against.'
    }
    $ChecksumText = [string](Get-Content -LiteralPath (Get-TempFile -Uri $ChecksumAsset.browser_download_url) -Raw)
    $ExpectedHash = $null
    foreach ($Line in $ChecksumText | Split-LineEndings) {
      $Entries = $Line -split '\s+'
      if ($Entries[0] -match '^[0-9a-fA-F]{64}$' -and $Entries[1].TrimStart('*') -eq $Asset.name) {
        $ExpectedHash = $Entries[0]
        break
      }
    }
    if (-not $ExpectedHash) {
      throw "SHA256SUMS.txt does not list $($Asset.name)."
    }
    if ((Get-FileHash -LiteralPath $InstallerFile -Algorithm SHA256).Hash -ine $ExpectedHash) {
      throw 'The downloaded installer does not match the SHA-256 published in SHA256SUMS.txt.'
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = [string]$Object1.html_url
      }

      if ([string]::IsNullOrWhiteSpace($Object1.body)) {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      } else {
        # The body is English only, and its trailing "### Install / Upgrade" section lists package
        # managers, gatekeeper workarounds, and where the checksums live.
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $ReleaseNotesNodes = [System.Collections.Generic.List[object]]::new()
        $Skip = $false
        $SkippedHeadingLevel = 0
        foreach ($Node in $ReleaseNotesObject.ChildNodes) {
          if ($Node.Name -match '^h([1-6])$') {
            $HeadingLevel = [int]$Matches[1]
            if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
              $Skip = $Node.InnerText -match '(?i)^\s*(Downloads?|Hash(?:es)?|Checksums?|SHA-256|Installs?(?:\s*/\s*Upgrades?)?)\s*$'
              if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
            }
          }
          if ($Skip -or $Node.Name -eq 'h1') { continue }
          $ReleaseNotesNodes.Add($Node)
        }

        $ReleaseNotes = $ReleaseNotesNodes | Get-TextContent | Format-Text
        if ([string]::IsNullOrWhiteSpace($ReleaseNotes)) {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        } else {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotes
          }
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
