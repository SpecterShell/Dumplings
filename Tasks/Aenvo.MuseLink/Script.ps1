$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/Aenvo/MuseLink/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
  throw 'The latest release tag does not provide a numeric version.'
}

# Installer
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('x64') -and $_.name -match 'setup' -and $_.name -notmatch 'portable|update' }, 'First')[0]
if (-not $Asset) {
  throw 'The latest release does not provide a Windows x64 setup installer.'
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

    $ChecksumAsset = $Object1.assets.Where({ $_.name.EndsWith('.txt') -and $_.name -match 'SHA256SUMS' }, 'First')[0]
    if (-not $ChecksumAsset) {
      $this.Log("No SHA256SUMS.txt asset for version $($this.CurrentState.Version), so the downloaded installer is not verified", 'Warning')
    } else {
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
        $this.Log("SHA256SUMS.txt does not list $($Asset.name), so the downloaded installer is not verified", 'Warning')
      } elseif ((Get-FileHash -LiteralPath $InstallerFile -Algorithm SHA256).Hash -ine $ExpectedHash) {
        throw "The downloaded installer does not match the SHA-256 published in $($ChecksumAsset.name)."
      }
    }

    try {
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = [string]$Object1.html_url
      }
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = [string]$Object1.html_url
      }

      if ([string]::IsNullOrWhiteSpace($Object1.body)) {
        $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
      } else {
        # The body repeats every section per language: "## Windows x64" holds the download table and
        # the Chinese changes, and "## English" holds the download text and the English changes.
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $TitlePatterns = [ordered]@{
          'zh-CN' = '本版本更新'
          'en-US' = "What'?s new"
        }
        foreach ($Locale in $TitlePatterns.Keys) {
          $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectNodes('./h2|./h3').Where({ $_.InnerText -match $TitlePatterns[$Locale] }, 'First')[0]
          if (-not $ReleaseNotesTitleNode) {
            $this.Log("No ReleaseNotes ($Locale) for version $($this.CurrentState.Version)", 'Warning')
            continue
          }

          $Skip = $false
          $SkippedHeadingLevel = 0
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -notmatch '^h[12]$'; $Node = $Node.NextSibling) {
            if ($Node.Name -match '^h([1-6])$') {
              $HeadingLevel = [int]$Matches[1]
              if (-not $Skip -or $HeadingLevel -le $SkippedHeadingLevel) {
                $Skip = $Node.InnerText -match '(?i)^\s*(Downloads?|Hash(?:es)?|Checksums?|SHA-256|下载|校验和)\s*$'
                if ($Skip) { $SkippedHeadingLevel = $HeadingLevel }
              }
            }
            # A table in this body is a download and checksum listing, never a change entry.
            if (-not $Skip -and $Node.Name -ne 'table') { $Node }
          }
          $ReleaseNotes = $ReleaseNotesNodes | Get-TextContent | Format-Text
          if ([string]::IsNullOrWhiteSpace($ReleaseNotes)) {
            $this.Log("No ReleaseNotes ($Locale) for version $($this.CurrentState.Version)", 'Warning')
            continue
          }

          # ReleaseNotes ($Locale)
          $this.CurrentState.Locale += [ordered]@{
            Locale = $Locale
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
