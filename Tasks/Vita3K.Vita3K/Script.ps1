function Read-Installer {
  $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  $InstallerFileExtracted = New-TempFolder
  7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'Vita3K.exe' | Out-Host
  $InstallerFile2 = Join-Path $InstallerFileExtracted 'Vita3K.exe'
  # Version
  $this.CurrentState.Version = $InstallerFile2 | Read-ProductVersionFromExe
  Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

function Get-ReleaseNotes {
  try {
    # ReleaseNotesUrl (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotesUrl'
      Value  = 'https://github.com/Vita3K/Vita3K-builds/releases'
    }

    $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/Vita3K/Vita3K-builds/releases/tags/$($this.CurrentState.Version.Split('.')[-1])"

    if (-not [string]::IsNullOrWhiteSpace($Object2.body)) {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
      }
    } else {
      $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }

    # ReleaseNotesUrl (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotesUrl'
      Value  = $Object2.html_url
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/Vita3K/Vita3K/releases/latest'

# Installer
$AssetX64 = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name -match 'windows' -and $_.name -notmatch 'arm64' }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $AssetX64.browser_download_url | ConvertTo-UnescapedUri
}
$AssetARM64 = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name -match 'windows' -and $_.name -match 'arm64' }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $AssetARM64.browser_download_url | ConvertTo-UnescapedUri
}

# Hash
$this.CurrentState.Hash = $AssetX64.digest

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The hash is unchanged
if ($this.CurrentState.Hash -eq $this.LastState.Hash) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

switch -Regex ($this.Check()) {
  # Case 5: The hash and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 4: The hash has changed, but the version is not
  default {
    $this.Log('The hash has changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
