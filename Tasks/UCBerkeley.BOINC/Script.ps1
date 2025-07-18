$Object1 = Invoke-RestMethod -Uri 'https://boinc.berkeley.edu/download_all.php?xml=1'
# x64
$Object2 = $Object1.versions.version.Where({ $_.dbplatform -eq 'windows_x86_64' }, 'First')[0]
# arm64
$Object3 = $Object1.versions.version.Where({ $_.dbplatform -eq 'windows_arm64' }, 'First')[0]

if ($Object2.version_num -ne $Object3.version_num) {
  $this.Log("Inconsistent versions: x64: $($Object2.version_num), arm64: $($Object3.version_num)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object2.version_num

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object3.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = New-TempFolder
      7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFileExtracted}" $InstallerFile '2.msi' | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted '2.msi'
      # Version
      $this.CurrentState.Version = $InstallerFile2 | Read-ProductVersionFromMsi
      # ProductCode
      $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries
      $Installer['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
        }
      )
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    }

    try {
      $RepoOwner = 'BOINC'
      $RepoName = 'boinc'

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://github.com/${RepoOwner}/${RepoName}/releases"
      }

      $Object5 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/tags/client_release%2F$($this.CurrentState.Version.Split('.')[0..1] -join '.')%2F$($this.CurrentState.Version)"

      if (-not [string]::IsNullOrWhiteSpace($Object5.body)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object5.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object5.html_url
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
