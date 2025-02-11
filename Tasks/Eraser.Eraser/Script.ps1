$ProjectName = 'eraser'
$RootPath = ''

$Object1 = Invoke-RestMethod -Uri "https://sourceforge.net/projects/${ProjectName}/rss?path=${RootPath}"
$Assets = $Object1.Where({ $_.title.'#cdata-section' -match "^$([regex]::Escape($RootPath))" -and $_.title.'#cdata-section' -match 'Eraser (\d+(?:\.\d+)+)\.exe' -and $_.title.'#cdata-section' -notmatch 'Alpha' })

# Version
$this.CurrentState.Version = [regex]::Match($Assets[0].title.'#cdata-section', 'Eraser (\d+(?:\.\d+)+)\.exe').Groups[1].Value

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Assets[0].link | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Assets[0].link | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $Assets[0].pubDate,
        'ddd, dd MMM yyyy HH:mm:ss "UT"',
        (Get-Culture -Name 'en-US')
      ) | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl -UserAgent $WinGetUserAgent
    # InstallerSha256
    $InstallerX86['InstallerSha256'] = $InstallerX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'Eraser (x86).msi' 'Eraser (x64).msi' | Out-Host

    $InstallerFile2 = Join-Path $InstallerFileExtracted 'Eraser (x86).msi'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
    # AppsAndFeaturesEntries + ProductCode
    $InstallerX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $InstallerX86['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )

    $InstallerFile3 = Join-Path $InstallerFileExtracted 'Eraser (x64).msi'
    # RealVersion
    $this.CurrentState.RealVersion ??= $InstallerFile3 | Read-ProductVersionFromMsi
    # AppsAndFeaturesEntries + ProductCode
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $InstallerX64['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )

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
