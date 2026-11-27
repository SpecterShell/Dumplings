$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/amanthanvi/noctty/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

if ($this.CurrentState.Version -notmatch '^[0-9]+(\.[0-9]+)*$') {
  throw 'The latest release tag does not provide a numeric version.'
}

# Installer
# releases/latest ignores the prerelease candidates the project publishes between stable builds, so it
# returns the current stable release. The -portable.zip and -symbols.zip assets are not installers.
$AssetX64 = $Object1.assets.Where({ $_.name.EndsWith('-setup.exe') -and $_.name.Contains('-windows-x64-') }, 'First')[0]
$AssetArm64 = $Object1.assets.Where({ $_.name.EndsWith('-setup.exe') -and $_.name.Contains('-windows-arm64-') }, 'First')[0]
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

    # Each architecture publishes its own SHA256SUMS-windows-<architecture>.txt listing. The entries
    # name the asset with a leading * for binary mode, so match on the recorded filename.
    foreach ($Pair in @(@($AssetX64, 'x64'), @($AssetArm64, 'arm64'))) {
      $Asset = $Pair[0]
      $ChecksumAsset = $Object1.assets.Where({ $_.name -eq "SHA256SUMS-windows-$($Pair[1]).txt" }, 'First')[0]
      if (-not $ChecksumAsset) {
        throw "The latest release does not provide SHA256SUMS-windows-$($Pair[1]).txt."
      }
      $InstallerUrl = $Asset.browser_download_url | ConvertTo-UnescapedUri
      $this.InstallerFiles[$InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerUrl
      $ExpectedHash = $null
      foreach ($Line in ([string](Get-Content -LiteralPath (Get-TempFile -Uri $ChecksumAsset.browser_download_url) -Raw) | Split-LineEndings)) {
        $Entries = $Line -split '\s+'
        if ($Entries[0] -match '^[0-9a-fA-F]{64}$' -and $Entries[1].TrimStart('*') -eq $Asset.name) {
          $ExpectedHash = $Entries[0]
          break
        }
      }
      if (-not $ExpectedHash) {
        throw "$($ChecksumAsset.name) does not list $($Asset.name)."
      }
      if ((Get-FileHash -LiteralPath $InstallerFile -Algorithm SHA256).Hash -ine $ExpectedHash) {
        throw "The downloaded $($Asset.name) does not match the SHA-256 published in $($ChecksumAsset.name)."
      }
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = [string]$Object1.html_url
      }

      # The body is a prose changelog that runs past the schema's 10000-character ReleaseNotes limit,
      # so the release supplies no ReleaseNotes.
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
