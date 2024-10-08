$Object1 = (Invoke-RestMethod -Uri 'https://www.python.org/api/v2/downloads/release/?version=3&pre_release=false') |
  Where-Object -FilterScript { $_.name.Contains('3.13.') } |
  Sort-Object -Property { $_.name -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

$Object2 = (Invoke-RestMethod -Uri "https://www.python.org/api/v2/downloads/release_file/?os=1&release=$([regex]::Match($Object1.resource_uri, 'release/(\d+)/').Groups[1].Value)")

# Version
$this.CurrentState.Version = $Version = [regex]::Match($Object1.name, 'Python ([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.Where({ $_.name.Contains('installer') -and $_.name -match '32\s*-bit' }, 'First')[0].url
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.Where({ $_.name.Contains('installer') -and $_.name -match '64\s*-bit' }, 'First')[0].url
}
$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object2.Where({ $_.name.Contains('installer') -and $_.name -match 'ARM64' }, 'First')[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object1.release_notes_url
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    # AppsAndFeaturesEntries
    $InstallerFileX86 = Get-TempFile -Uri $InstallerX86.InstallerUrl
    $InstallerFileX64 = Get-TempFile -Uri $InstallerX64.InstallerUrl
    $InstallerFileARM64 = Get-TempFile -Uri $InstallerARM64.InstallerUrl

    $RealVersion = $InstallerFileX64 | Read-ProductVersionFromExe

    $InstallerX86['InstallerSha256'] = (Get-FileHash -Path $InstallerFileX86 -Algorithm SHA256).Hash
    $InstallerX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = "Python ${Version} (32-bit)"
        DisplayVersion = $RealVersion
        ProductCode    = $InstallerX86['ProductCode'] = $InstallerFileX86 | Read-ProductCodeFromBurn
        UpgradeCode    = $InstallerFileX86 | Read-UpgradeCodeFromBurn
      }
    )

    $InstallerX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileX64 -Algorithm SHA256).Hash
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = "Python ${Version} (64-bit)"
        DisplayVersion = $RealVersion
        ProductCode    = $InstallerX64['ProductCode'] = $InstallerFileX64 | Read-ProductCodeFromBurn
        UpgradeCode    = $InstallerFileX64 | Read-UpgradeCodeFromBurn
      }
    )

    $InstallerARM64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileARM64 -Algorithm SHA256).Hash
    $InstallerARM64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = "Python ${Version} (ARM64)"
        DisplayVersion = $RealVersion
        ProductCode    = $InstallerARM64['ProductCode'] = $InstallerFileARM64 | Read-ProductCodeFromBurn
        UpgradeCode    = $InstallerFileARM64 | Read-UpgradeCodeFromBurn
      }
    )

    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@id='python-$($Version.Replace('.', '-'))-final']")

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $ReleaseNotesNode.SelectSingleNode('./p[1]//text()').InnerText,
        '(\d{4}-\d{1,2}-\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = ($ReleaseNotesNode.SelectNodes('./p[1]/following-sibling::node()') | Get-TextContent | Format-Text).Replace('¶', '')
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
