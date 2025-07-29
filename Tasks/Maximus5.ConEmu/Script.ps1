$RepoOwner = 'ConEmu'
$RepoName = 'ConEmu'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('Setup') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('Setup') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
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

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFileExtracted}" $InstallerFile '2.msi' '3.msi' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted '2.msi'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
    # ProductCode
    $InstallerX86['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $InstallerX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName   = $InstallerFile2 | Read-ProductNameFromMsi
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )
    $InstallerFile3 = Join-Path $InstallerFileExtracted '3.msi'
    # ProductCode
    $InstallerX64['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName   = $InstallerFile3 | Read-ProductNameFromMsi
        UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = 'https://conemu.github.io/en/Whats_New.html'
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[@id='Build_$($this.CurrentState.Version.Replace('.', ''))']")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = Join-Uri $ReleaseNotesUrl $ReleaseNotesTitleNode.SelectSingleNode('./a').Attributes['href'].Value
        }

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
