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

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $WinGetInstallerFiles[$InstallerX64.InstallerUrl] = $InstallerFileX64 = Get-TempFile -Uri $InstallerX64.InstallerUrl
    $InstallerFileX642 = $InstallerFileX64 | Expand-TempArchive | Join-Path -ChildPath $InstallerX64.NestedInstallerFiles[0].RelativeFilePath
    $InstallerFileX642Extracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileX642Extracted}" $InstallerFileX642 'x64\PaintDotNet_x64.msi' | Out-Host
    $InstallerFileX643 = Join-Path $InstallerFileX642Extracted 'PaintDotNet_x64.msi'
    # AppsAndFeaturesEntries + ProductCode
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $InstallerX64['ProductCode'] = $InstallerFileX643 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFileX643 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )

    $WinGetInstallerFiles[$InstallerARM64.InstallerUrl] = $InstallerFileARM64 = Get-TempFile -Uri $InstallerARM64.InstallerUrl
    $InstallerFileARM642 = $InstallerFileARM64 | Expand-TempArchive | Join-Path -ChildPath $InstallerARM64.NestedInstallerFiles[0].RelativeFilePath
    $InstallerFileARM642Extracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileARM642Extracted}" $InstallerFileARM642 'arm64\PaintDotNet_arm64.msi' | Out-Host
    $InstallerFileARM643 = Join-Path $InstallerFileARM642Extracted 'PaintDotNet_arm64.msi'
    # AppsAndFeaturesEntries + ProductCode
    $InstallerARM64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $InstallerARM64['ProductCode'] = $InstallerFileARM643 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFileARM643 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )

    try {
      $Object2 = [System.IO.StringReader]::new((Invoke-WebRequest -Uri 'https://getpaint.net/roadmap.html' | ConvertFrom-Html | Get-TextContent))

      while ($Object2.Peek() -ne -1) {
        $String = $Object2.ReadLine()
        if ($String -match "^Paint\.NET $([regex]::Escape($this.CurrentState.Version))") {
          try {
            # ReleaseTime
            $this.CurrentState.ReleaseTime ??= [datetime]::ParseExact(
              [regex]::Match($String, '([a-zA-Z]+\W+\d{1,2}(st|nd|rd|th)\W+20\d{2})').Groups[1].Value,
              # "[string[]]" is needed here to convert "array" object to string array
              [string[]]@(
                "MMMM d'st', yyyy",
                "MMMM d'nd', yyyy",
                "MMMM d'rd', yyyy",
                "MMMM d'th', yyyy"
              ),
              (Get-Culture -Name 'en-US'),
              [System.Globalization.DateTimeStyles]::None
            ).ToString('yyyy-MM-dd')
          } catch {
            $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          }
          break
        }
      }
      if ($Object2.Peek() -ne -1) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while ($Object2.Peek() -ne -1) {
          $String = $Object2.ReadLine()
          if ($String -notmatch '^Paint\.NET (\d+(?:\.\d+)+)') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      $Object2.Close()
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
