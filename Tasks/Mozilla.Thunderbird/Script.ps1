# Unrecognized locales for WinGet: cak (Kaqchikel)
$Locales = @('en-US', 'af', 'ar', 'ast', 'be', 'bg', 'br', 'ca', 'cak', 'cs', 'cy', 'da', 'de', 'dsb', 'el', 'en-CA', 'en-GB', 'es-AR', 'es-ES', 'es-MX', 'et', 'eu', 'fi', 'fr', 'fy-NL', 'ga-IE', 'gd', 'gl', 'he', 'hr', 'hsb', 'hu', 'hy-AM', 'id', 'is', 'it', 'ja', 'ka', 'kab', 'kk', 'ko', 'lt', 'lv', 'ms', 'nb-NO', 'nl', 'nn-NO', 'pa-IN', 'pl', 'pt-BR', 'pt-PT', 'rm', 'ro', 'ru', 'sk', 'sl', 'sq', 'sr', 'sv-SE', 'th', 'tr', 'uk', 'uz', 'vi', 'zh-CN', 'zh-TW', 'multi')
$ArchMap = [ordered]@{
  x86   = 'win32'
  x64   = 'win64'
  arm64 = 'win64-aarch64'
}
$Prefix = 'https://download-installer.cdn.mozilla.net/pub/thunderbird/releases/'

$Object1 = Invoke-RestMethod -Uri 'https://product-details.mozilla.org/1.0/thunderbird_versions.json'

# Version
$OriginalVersion = $Object1.LATEST_THUNDERBIRD_VERSION
$this.CurrentState.Version = $ShortVersion = $OriginalVersion.Replace('esr', '')

$Object2 = [ordered]@{}
Invoke-RestMethod -Uri "${Prefix}${OriginalVersion}/SHA256SUMS" | Split-LineEndings |
  Where-Object -FilterScript { $_ -match '(win32|win64|win64-aarch64)/' -and $_ -match '\.(exe|msix)$' -and -not $_.Contains('Thunderbird Installer') } |
  ForEach-Object -Process {
    $Entries = $_.Split('  ')
    $Object2[$Entries[1]] = $Entries[0].ToUpper()
  }

# Installer
foreach ($Locale in @('en-US')) {
  foreach ($Arch in @('x86', 'x64')) {
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture    = $Arch
      InstallerType   = 'nullsoft'
      InstallerUrl    = "${Prefix}${OriginalVersion}/$($ArchMap[$Arch])/${Locale}/Thunderbird Setup ${OriginalVersion}.exe"
      InstallerSha256 = $Object2["$($ArchMap[$Arch])/${Locale}/Thunderbird Setup ${OriginalVersion}.exe"]
      ProductCode     = "Mozilla Thunderbird ${ShortVersion} (${Arch} ${Locale})"
    }
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = "https://www.thunderbird.net/thunderbird/${OriginalVersion}/releasenotes/"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-RestMethod -Uri 'https://product-details.mozilla.org/1.0/thunderbird.json'

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.releases."thunderbird-${OriginalVersion}".date | Get-Date -Format 'yyyy-MM-dd'

    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object4 = curl -fsSLA $DumplingsInternetExplorerUserAgent $ReleaseNotesUrl | Join-String -Separator "`n" | ConvertFrom-Html

      # Remove headers
      $Object4.SelectNodes('//section[contains(./div/@class, "release-notes-container")]//div[@class="see-all-releases"]').ForEach({ $_.Remove() })

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object4.SelectSingleNode('//section[contains(./div/@class, "release-notes-container")]') | Get-TextContent | Format-Text
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
    $this.MessageEnabled = $false
  }
  'Updated' {
    $WinGetIdentifierPrefix = $this.Config.WinGetIdentifier

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockMozilla')
    $Mutex.WaitOne(3600000) | Out-Null

    foreach ($Locale in $Locales) {
      $this.CurrentState.Installer = @()

      if ($Locale -eq 'multi') {
        $this.Config.WinGetIdentifier = "${WinGetIdentifierPrefix}.MSIX"

        foreach ($Arch in @('x86', 'x64')) {
          # Installer
          $this.CurrentState.Installer += [ordered]@{
            Architecture  = $Arch
            InstallerType = 'msix'
            InstallerUrl  = "${Prefix}${OriginalVersion}/$($ArchMap[$Arch])/${Locale}/Thunderbird Setup ${OriginalVersion}.msix"
          }
        }
      } else {
        if ($Locale -eq 'en-US') {
          $this.Config.WinGetIdentifier = $WinGetIdentifierPrefix
        } else {
          $this.Config.WinGetIdentifier = "${WinGetIdentifierPrefix}.${Locale}"
        }

        foreach ($Arch in @('x86', 'x64')) {
          # Installer
          $this.CurrentState.Installer += [ordered]@{
            Architecture    = $Arch
            InstallerType   = 'nullsoft'
            InstallerUrl    = "${Prefix}${OriginalVersion}/$($ArchMap[$Arch])/${Locale}/Thunderbird Setup ${OriginalVersion}.exe"
            InstallerSha256 = $Object2["$($ArchMap[$Arch])/${Locale}/Thunderbird Setup ${OriginalVersion}.exe"]
            ProductCode     = "Mozilla Thunderbird ${ShortVersion} (${Arch} ${Locale})"
          }
        }
      }

      try {
        $this.Submit()
      } catch {
        $_ | Out-Host
        $this.Log($_, 'Warning')
      }

      Start-Sleep -Seconds 20
    }

    $Mutex.ReleaseMutex()
    $Mutex.Dispose()
  }
  'Changed|Updated' {
    $this.Message()
  }
}
