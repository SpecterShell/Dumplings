$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/RitualDev-Lab/poly/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# The Windows archive holds one portable poly.exe at its root, so NestedInstallerFiles stays as authored.
# The darwin, linux, and install.sh assets are the other platforms and the one-line bootstrappers.
$AssetX64 = $Object1.assets.Where({ $_.name -eq 'poly-windows-x64.zip' }, 'First')[0]
if (-not $AssetX64) {
  throw 'The latest release does not provide the Windows x64 archive.'
}
$InstallerUrl = $AssetX64.browser_download_url | ConvertTo-UnescapedUri
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = $InstallerUrl
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

    # checksums.txt records the SHA-256 of every release asset, so confirm the archive before the manifest pipeline hashes it.
    $ChecksumAsset = $Object1.assets.Where({ $_.name -eq 'checksums.txt' }, 'First')[0]
    if (-not $ChecksumAsset) {
      throw 'The latest release does not provide checksums.txt to verify the installer against.'
    }
    $ExpectedHash = $null
    foreach ($Line in ([string](Get-Content -LiteralPath (Get-TempFile -Uri $ChecksumAsset.browser_download_url) -Raw) | Split-LineEndings)) {
      $Entries = $Line -split '\s+'
      if ($Entries.Count -ge 2 -and $Entries[0] -match '^[0-9a-fA-F]{64}$' -and $Entries[1].TrimStart('*') -eq $AssetX64.name) {
        $ExpectedHash = $Entries[0]
      }
    }
    if (-not $ExpectedHash) {
      throw "checksums.txt does not list $($AssetX64.name)."
    }
    $this.InstallerFiles[$InstallerUrl] = $InstallerFile = Get-TempFile -Uri $AssetX64.browser_download_url
    if ((Get-FileHash -LiteralPath $InstallerFile -Algorithm SHA256).Hash -ine $ExpectedHash) {
      throw "The downloaded $($AssetX64.name) does not match the SHA-256 published in checksums.txt."
    }

    try {
      # The release body carries no text, so take the version section of the repository changelog instead.
      $Changelog = [string](Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/RitualDev-Lab/poly/HEAD/CHANGELOG.md')
      $Heading = [regex]::Match($Changelog, "(?m)^## \[$([regex]::Escape($this.CurrentState.Version))\][^\r\n]*").Value
      if (-not $Heading) {
        $this.Log("No CHANGELOG.md section for version $($this.CurrentState.Version)", 'Warning')
      } else {
        $Section = [regex]::Match($Changelog.Substring($Changelog.IndexOf($Heading)), '(?ms)^[^\r\n]*\r?\n(?<Body>.*?)(?=^## \[|\z)').Groups['Body'].Value
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Section | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }

        # GitHub builds the heading anchor from the title text, drops punctuation other than hyphens, and turns every space into a hyphen.
        $Anchor = $Heading -replace '^## ', '' -replace '[^\w -]', '' -replace ' ', '-'
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = "https://github.com/RitualDev-Lab/poly/blob/HEAD/CHANGELOG.md#$Anchor"
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
