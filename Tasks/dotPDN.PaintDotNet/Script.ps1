$RepoOwner = 'paintdotnet'
$RepoName = 'release'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture         = 'x64'
  NestedInstallerType  = 'exe'
  InstallerUrl         = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('install') -and $_.name.Contains('x64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "paint.net.$($this.CurrentState.Version).install.x64.exe"
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  NestedInstallerType  = 'wix'
  InstallerUrl         = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('winmsi') -and $_.name.Contains('x64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "paint.net.$($this.CurrentState.Version).winmsi.x64.msi"
    }
  )
}
$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture         = 'arm64'
  NestedInstallerType  = 'exe'
  InstallerUrl         = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('install') -and $_.name.Contains('arm64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "paint.net.$($this.CurrentState.Version).install.arm64.exe"
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm64'
  NestedInstallerType  = 'wix'
  InstallerUrl         = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('winmsi') -and $_.name.Contains('arm64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "paint.net.$($this.CurrentState.Version).winmsi.arm64.msi"
    }
  )
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFileX64 = Get-TempFile -Uri $InstallerX64.InstallerUrl
    $NestedInstallerFileX64 = $InstallerFileX64 | Expand-TempArchive | Join-Path -ChildPath $InstallerX64.NestedInstallerFiles[0].RelativeFilePath
    $ExtractedNestedInstallerFileX64 = New-TempFolder
    7z e -aoa -ba -bd -o"${ExtractedNestedInstallerFileX64}" $NestedInstallerFileX64 'x64\PaintDotNet_x64.msi'
    $RealInstallerFileX64 = Join-Path $ExtractedNestedInstallerFileX64 'PaintDotNet_x64.msi'

    $InstallerX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileX64 -Algorithm SHA256).Hash
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $InstallerX64['ProductCode'] = $RealInstallerFileX64 | Read-ProductCodeFromMsi
        UpgradeCode   = $RealInstallerFileX64 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )

    $InstallerFileARM64 = Get-TempFile -Uri $InstallerARM64.InstallerUrl
    $NestedInstallerFileARM64 = $InstallerFileARM64 | Expand-TempArchive | Join-Path -ChildPath $InstallerARM64.NestedInstallerFiles[0].RelativeFilePath
    $ExtractedNestedInstallerFileARM64 = New-TempFolder
    7z e -aoa -ba -bd -o"${ExtractedNestedInstallerFileARM64}" $NestedInstallerFileARM64 'arm64\PaintDotNet_arm64.msi'
    $RealInstallerFileARM64 = Join-Path $ExtractedNestedInstallerFileARM64 'PaintDotNet_arm64.msi'

    $InstallerARM64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileARM64 -Algorithm SHA256).Hash
    $InstallerARM64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $InstallerARM64['ProductCode'] = $RealInstallerFileARM64 | Read-ProductCodeFromMsi
        UpgradeCode   = $RealInstallerFileARM64 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )

    try {
      $Object2 = Invoke-RestMethod -Uri 'https://www.getpaint.net/updates/v9/manifest.os1000.x64.json'

      if ($Object2.releases[0].'display-name'.Contains($this.CurrentState.Version)) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl = $Object2.releases[0].'more-info-url'
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object1.html_url
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.html_url
      }
    }

    try {
      if (Test-Path -Path Variable:\ReleaseNotesUrl) {
        $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

        $ReleaseNotesTitleNode = $Object3.SelectSingleNode('//div[@data-role="commentContent"]/h2[contains(text(), "Change Log")]')
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node; $Node = $Node.NextSibling) { $Node }
        if ($ReleaseNotesNodes) {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
