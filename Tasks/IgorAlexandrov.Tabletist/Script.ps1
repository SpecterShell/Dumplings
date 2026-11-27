$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/igor-alexandrov/tabletist/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
  throw 'The latest release tag does not provide a numeric version.'
}

# Installer
$AssetX64 = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match 'setup' -and $_.name.Contains('x86_64') -and $_.name -notmatch 'portable|update' }, 'First')[0]
$AssetArm64 = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name -match 'setup' -and $_.name.Contains('aarch64') -and $_.name -notmatch 'portable|update' }, 'First')[0]
if (-not $AssetX64 -or -not $AssetArm64) {
  throw 'The latest release does not provide both Windows x64 and Arm64 setup installers.'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = $AssetX64.browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'inno'
  InstallerUrl  = $AssetArm64.browser_download_url | ConvertTo-UnescapedUri
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

    $ChecksumAsset = $Object1.assets.Where({ $_.name -eq 'checksums.txt' }, 'First')[0]
    if (-not $ChecksumAsset) {
      throw 'The latest release does not provide checksums.txt to verify the installers against.'
    }
    $ChecksumTable = @{}
    foreach ($Line in ([string](Get-Content -LiteralPath (Get-TempFile -Uri $ChecksumAsset.browser_download_url) -Raw) | Split-LineEndings)) {
      $Entries = $Line -split '\s+'
      if ($Entries[0] -match '^[0-9a-fA-F]{64}$') { $ChecksumTable[$Entries[1].TrimStart('*')] = $Entries[0] }
    }
    foreach ($Asset in @($AssetX64, $AssetArm64)) {
      $InstallerUrl = $Asset.browser_download_url | ConvertTo-UnescapedUri
      $this.InstallerFiles[$InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerUrl
      $ExpectedHash = $ChecksumTable[$Asset.name]
      if (-not $ExpectedHash) {
        throw "checksums.txt does not list $($Asset.name)."
      }
      if ((Get-FileHash -LiteralPath $InstallerFile -Algorithm SHA256).Hash -ine $ExpectedHash) {
        throw "The downloaded $($Asset.name) does not match the SHA-256 published in checksums.txt."
      }
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
        # The body is the English GitHub comparison listing; "New Contributors" and the trailing
        # Full Changelog line are repository metadata rather than product changes.
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $ReleaseNotesNodes = [System.Collections.Generic.List[object]]::new()
        $Skip = $false
        $SkippedHeadingLevel = 0
        foreach ($Node in $ReleaseNotesObject.ChildNodes) {
          if ($Node.Name -match '^h([1-6])$') {
            $HeadingLevel = [int]$Matches[1]
            if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
              $Skip = $Node.InnerText -match '(?i)^\s*(Downloads?|Hash(?:es)?|Checksums?|SHA-256|New Contributors|Full Changelog)\s*$'
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
