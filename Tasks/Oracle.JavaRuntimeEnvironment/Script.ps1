# The version only appears in the x64 installer page
$Object1 = Invoke-WebRequest -Uri 'https://www.java.com/en/download/' -UserAgent $DumplingsBrowserUserAgent -Headers @{ Accept = '*/*'; Connection = 'close' }

$VersionMatches = [regex]::Match($Object1.Content, 'Version (\d+) Update (\d+)')

# Java 9+ has different version scheme
if ($VersionMatches.Groups[1].Value -ne '8') {
  throw 'Unsupported version'
}

# Version
$this.CurrentState.Version = "1.8.0_$($VersionMatches.Groups[2].Value)"

$Object2 = Invoke-WebRequest -Uri 'https://www.java.com/en/download/manual.jsp' -UserAgent $DumplingsBrowserUserAgent -Headers @{ Accept = '*/*'; Connection = 'close' }

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.Links.Where({ try { $_.outerHTML.Contains('Windows Offline') -and -not $_.outerHTML.Contains('64-bit') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.Links.Where({ try { $_.outerHTML.Contains('Windows Offline') -and $_.outerHTML.Contains('64-bit') } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object1.Content, 'Release date: ([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$InstallerX86.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerX86.InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFileExtracted}" $InstallerFile '2.wrapper_jre_offline.exe' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted '2.wrapper_jre_offline.exe'
    $InstallerFile2Extracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFile2Extracted}" $InstallerFile2 '2.msi' | Out-Host
    $InstallerFile3 = Join-Path $InstallerFile2Extracted '2.msi'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile3 | Read-ProductVersionFromMsi
    # AppsAndFeaturesEntries + ProductCode
    $InstallerX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName   = "Java 8 Update $($VersionMatches.Groups[2].Value)"
        ProductCode   = $InstallerX86['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )
    Remove-Item -Path $InstallerFile2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    $this.InstallerFiles[$InstallerX64.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerX64.InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFileExtracted}" $InstallerFile '2.wrapper_jre_offline.exe' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted '2.wrapper_jre_offline.exe'
    $InstallerFile2Extracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFile2Extracted}" $InstallerFile2 '2.msi' | Out-Host
    $InstallerFile3 = Join-Path $InstallerFile2Extracted '2.msi'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile3 | Read-ProductVersionFromMsi
    # AppsAndFeaturesEntries + ProductCode
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName   = "Java 8 Update $($VersionMatches.Groups[2].Value) (64-bit)"
        ProductCode   = $InstallerX64['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )
    Remove-Item -Path $InstallerFile2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'


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
