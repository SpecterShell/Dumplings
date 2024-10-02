# The following locales can't be matched by WinGet properly and thus are omitted: cak (Kaqchikel)
$Locales = @('en-US', 'af', 'ar', 'ast', 'be', 'bg', 'br', 'ca', 'cs', 'cy', 'da', 'de', 'dsb', 'el', 'en-CA', 'en-GB', 'es-AR', 'es-ES', 'es-MX', 'et', 'eu', 'fi', 'fr', 'fy-NL', 'ga-IE', 'gd', 'gl', 'he', 'hr', 'hsb', 'hu', 'hy-AM', 'id', 'is', 'it', 'ja', 'ka', 'kab', 'kk', 'ko', 'lt', 'lv', 'ms', 'nb-NO', 'nl', 'nn-NO', 'pa-IN', 'pl', 'pt-BR', 'pt-PT', 'rm', 'ro', 'ru', 'sk', 'sl', 'sq', 'sr', 'sv-SE', 'th', 'tr', 'uk', 'uz', 'vi', 'zh-CN', 'zh-TW', 'multi')
$ArchMap = [ordered]@{
  x86   = 'win32'
  x64   = 'win64'
  arm64 = 'win64-aarch64'
}
$Prefix = 'https://download-installer.cdn.mozilla.net/pub/thunderbird/releases/'

$Object1 = Invoke-RestMethod -Uri 'https://product-details.mozilla.org/1.0/thunderbird_versions.json'

# Version
$OriginalVersion = $Object1.THUNDERBIRD_ESR
$this.CurrentState.Version = $ShortVersion = $OriginalVersion.Replace('esr', '')

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
      $Object2 = Invoke-RestMethod -Uri 'https://product-details.mozilla.org/1.0/thunderbird.json'

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.releases."thunderbird-${OriginalVersion}".date | Get-Date -Format 'yyyy-MM-dd'

    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # Remove headers
      $Object3.SelectNodes('/html/body/main/section[contains(./div/@class, "release-notes-container")]//div[@class="see-all-releases"]').ForEach({ $_.Remove() })

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object3.SelectSingleNode('/html/body/main/section[contains(./div/@class, "release-notes-container")]') | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Updated' {
    $Object4 = [ordered]@{}
    Invoke-RestMethod -Uri "${Prefix}${OriginalVersion}/SHA256SUMS" | Split-LineEndings |
      Where-Object -FilterScript { $_ -match '(win32|win64|win64-aarch64)/' -and $_ -match '\.(exe|msix)$' -and -not $_.Contains('Thunderbird Installer') } |
      ForEach-Object -Process {
        $Entries = $_.Split('  ')
        $Object4[$Entries[1]] = $Entries[0].ToUpper()
      }

    foreach ($Locale in $Locales) {
      $this.CurrentState.Installer = @()

      if ($Locale -eq 'multi') {
        $this.Config.WinGetIdentifier = 'Mozilla.Thunderbird.MSIX'

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
          $this.Config.WinGetIdentifier = 'Mozilla.Thunderbird'
        } else {
          $this.Config.WinGetIdentifier = "Mozilla.Thunderbird.${Locale}"
        }

        foreach ($Arch in @('x86', 'x64')) {
          # Installer
          $this.CurrentState.Installer += [ordered]@{
            Architecture    = $Arch
            InstallerType   = 'nullsoft'
            InstallerUrl    = "${Prefix}${OriginalVersion}/$($ArchMap[$Arch])/${Locale}/Thunderbird Setup ${OriginalVersion}.exe"
            InstallerSha256 = $Object4["$($ArchMap[$Arch])/${Locale}/Thunderbird Setup ${OriginalVersion}.exe"]
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
    }
  }
  'Changed|Updated' {
    $this.Message()
  }
}
