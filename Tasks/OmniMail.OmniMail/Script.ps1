$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/mibgb65-cloud/OmniMail-APP/releases/latest'

# Version
# The NSIS script writes APP_VERSION, which the release workflow passes as the tag, straight into ARP
# DisplayVersion, so the tag keeps its leading v as the package version.
$this.CurrentState.Version = $Object1.tag_name

# Installer
# SHA256SUMS.txt is the checksum list and the beta assets live on the Pre-release, so releases/latest
# leaves only the stable Windows setup executable. The asset name carries no architecture token; the
# NSIS script requires RunningX64 and defines MULTIUSER_USE_PROGRAMFILES64.
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('-windows-') }, 'First')[0]
if (-not $Asset) {
  throw 'The latest release does not provide a Windows setup installer.'
}
$InstallerUrl = $Asset.browser_download_url | ConvertTo-UnescapedUri

# One entry updates both authored scope branches; the NSIS script selects them with /CurrentUser and
# /AllUsers while the installer binary and hash stay the same.
$this.CurrentState.Installer += [ordered]@{
  Query                = [ordered]@{ Architecture = 'x64'; InstallerType = 'nullsoft'; Scope = 'user' }
  InstallerUrl         = $InstallerUrl
  InstallationMetadata = [ordered]@{ DefaultInstallLocation = '%LocalAppData%\Programs\OmniMail' }
}
$this.CurrentState.Installer += [ordered]@{
  Query                = [ordered]@{ Architecture = 'x64'; InstallerType = 'nullsoft'; Scope = 'machine' }
  InstallerUrl         = $InstallerUrl
  InstallationMetadata = [ordered]@{ DefaultInstallLocation = '%ProgramFiles%\OmniMail' }
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

    # The release publishes SHA256SUMS.txt for every asset, so verify the installer against it.
    $ChecksumAsset = $Object1.assets.Where({ $_.name -eq 'SHA256SUMS.txt' }, 'First')[0]
    if (-not $ChecksumAsset) {
      throw 'The latest release does not provide SHA256SUMS.txt to verify the installer against.'
    }
    $ChecksumTable = @{}
    foreach ($Line in ([string](Get-Content -LiteralPath (Get-TempFile -Uri $ChecksumAsset.browser_download_url) -Raw) | Split-LineEndings)) {
      $Entries = $Line -split '\s+'
      if ($Entries[0] -match '^[0-9a-fA-F]{64}$') { $ChecksumTable[$Entries[1].TrimStart('*')] = $Entries[0] }
    }
    $ExpectedHash = $ChecksumTable[$Asset.name]
    if (-not $ExpectedHash) {
      throw "SHA256SUMS.txt does not list $($Asset.name)."
    }
    $this.InstallerFiles[$InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerUrl
    if ((Get-FileHash -LiteralPath $InstallerFile -Algorithm SHA256).Hash -ine $ExpectedHash) {
      throw "The downloaded $($Asset.name) does not match the SHA-256 published in SHA256SUMS.txt."
    }
    foreach ($Installer in $this.CurrentState.Installer) {
      $Installer['InstallerSha256'] = $ExpectedHash.ToUpperInvariant()
    }

    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = [string]$Object1.html_url
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      if ([string]::IsNullOrWhiteSpace($Object1.body)) {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      } else {
        # The release workflow posts docs/releases/<tag>.md as the release body, and the publisher writes
        # it in Chinese. The first section lists product changes; the following 安装与校验说明 section only
        # repeats the asset name and checksum note, so it is dropped at the next h2 boundary.
        # ReleaseNotes (zh-CN)
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode('(./h2)[1]')
        if ($ReleaseNotesTitleNode) {
          $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
