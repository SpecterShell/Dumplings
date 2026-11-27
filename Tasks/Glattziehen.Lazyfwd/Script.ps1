$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/glattziehen/lazyfwd/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
  throw 'The latest release tag does not provide a numeric version.'
}

# Installer
# Each Windows archive holds one portable lazyfwd.exe at its root, so NestedInstallerFiles stays as
# authored. The tar.gz assets are the Unix packages and install.sh and install.ps1 are bootstrappers.
$AssetX64 = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('_windows_amd64') }, 'First')[0]
$AssetArm64 = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('_windows_arm64') }, 'First')[0]
if (-not $AssetX64 -or -not $AssetArm64) {
  throw 'The latest release does not provide both Windows x64 and Arm64 archives.'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = $AssetX64.browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'arm64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = $AssetArm64.browser_download_url | ConvertTo-UnescapedUri
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

    # checksums.txt covers every goreleaser asset, so match the installers by their recorded names.
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
        # The Publish workflow passes the tag's CHANGELOG.md section as the release body, so the whole
        # text is the version's notes.
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
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
