# Unrecognized locales by WinGet: ach (Acholi/Acoli), cak (Kaqchikel), ia (Interlingua), lij (Ligurian), sc (Sardinian), sco (Scots), son (Songhai), szl (Silesian), trs (Triqui)
$Locales = @('en-US', 'ach', 'af', 'an', 'ar', 'ast', 'az', 'be', 'bg', 'bn', 'br', 'bs', 'ca-valencia', 'ca', 'cak', 'cs', 'cy', 'da', 'de', 'dsb', 'el', 'en-CA', 'en-GB', 'eo', 'es-AR', 'es-CL', 'es-ES', 'es-MX', 'et', 'eu', 'fa', 'ff', 'fi', 'fr', 'fur', 'fy-NL', 'ga-IE', 'gd', 'gl', 'gn', 'gu-IN', 'he', 'hi-IN', 'hr', 'hsb', 'hu', 'hy-AM', 'ia', 'id', 'is', 'it', 'ja', 'ka', 'kab', 'kk', 'km', 'kn', 'ko', 'lij', 'lt', 'lv', 'mk', 'mr', 'ms', 'my', 'nb-NO', 'ne-NP', 'nl', 'nn-NO', 'oc', 'pa-IN', 'pl', 'pt-BR', 'pt-PT', 'rm', 'ro', 'ru', 'sc', 'sco', 'si', 'sk', 'sl', 'son', 'sq', 'sr', 'sv-SE', 'szl', 'ta', 'te', 'tg', 'th', 'tl', 'tr', 'trs', 'uk', 'ur', 'uz', 'vi', 'xh', 'zh-CN', 'zh-TW', 'multi')
$ArchMap = [ordered]@{
  x86   = 'win32'
  x64   = 'win64'
  arm64 = 'win64-aarch64'
}
$Prefix = 'https://download-installer.cdn.mozilla.net/pub/firefox/releases/'

$Object1 = Invoke-RestMethod -Uri 'https://product-details.mozilla.org/1.0/firefox_versions.json'

# Version
$OriginalVersion = $Object1.FIREFOX_ESR
$this.CurrentState.Version = $ShortVersion = $OriginalVersion.Replace('esr', '')

$Object2 = [ordered]@{}
Invoke-RestMethod -Uri "${Prefix}${OriginalVersion}/SHA256SUMS" | Split-LineEndings |
  Where-Object -FilterScript { $_ -match '(win32|win64|win64-aarch64)/' -and $_ -match '\.(exe|msix)$' -and -not $_.Contains('Firefox Installer') } |
  ForEach-Object -Process {
    $Entries = $_.Split('  ')
    $Object2[$Entries[1]] = $Entries[0].ToUpper()
  }

# Installer
foreach ($Locale in @('en-US')) {
  foreach ($Arch in @('x86', 'x64', 'arm64')) {
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture    = $Arch
      InstallerType   = 'nullsoft'
      InstallerUrl    = "${Prefix}${OriginalVersion}/$($ArchMap[$Arch])/${Locale}/Firefox Setup ${OriginalVersion}.exe"
      InstallerSha256 = $Object2["$($ArchMap[$Arch])/${Locale}/Firefox Setup ${OriginalVersion}.exe"]
      ProductCode     = "Mozilla Firefox ${ShortVersion} ESR (${Arch} ${Locale})"
    }
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = "https://www.mozilla.org/firefox/${ShortVersion}/releasenotes/"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-RestMethod -Uri 'https://product-details.mozilla.org/1.0/firefox.json'

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.releases."firefox-${OriginalVersion}".date | Get-Date -Format 'yyyy-MM-dd'

    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object4 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # Remove MDN link (not clickable nor viewable in plain text)
      if ($MDNNode = $Object4.SelectSingleNode('//*[@id="note-mdn"]')) { $MDNNode.Remove() }

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object4.SelectSingleNode('//*[@class="c-release-notes"]') | Get-TextContent | Format-Text
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

        foreach ($Arch in @('x86', 'x64', 'arm64')) {
          # Installer
          $this.CurrentState.Installer += [ordered]@{
            Architecture  = $Arch
            InstallerType = 'msix'
            InstallerUrl  = "${Prefix}${OriginalVersion}/$($ArchMap[$Arch])/${Locale}/Firefox Setup ${OriginalVersion}.msix"
          }
        }
      } else {
        if ($Locale -eq 'en-US') {
          $this.Config.WinGetIdentifier = $WinGetIdentifierPrefix
        } else {
          $this.Config.WinGetIdentifier = "${WinGetIdentifierPrefix}.${Locale}"
        }

        foreach ($Arch in @('x86', 'x64', 'arm64')) {
          # Installer
          $this.CurrentState.Installer += [ordered]@{
            Architecture    = $Arch
            InstallerType   = 'nullsoft'
            InstallerUrl    = "${Prefix}${OriginalVersion}/$($ArchMap[$Arch])/${Locale}/Firefox Setup ${OriginalVersion}.exe"
            InstallerSha256 = $Object2["$($ArchMap[$Arch])/${Locale}/Firefox Setup ${OriginalVersion}.exe"]
            ProductCode     = "Mozilla Firefox ${ShortVersion} ESR (${Arch} ${Locale})"
          }
        }
      }

      try {
        $this.Submit()
      } catch {
        $_ | Out-Host
        $this.Log($_, 'Warning')
      }

      Start-Sleep -Seconds 30
    }

    $Mutex.ReleaseMutex()
    $Mutex.Dispose()
  }
  'Changed|Updated' {
    $this.Message()
  }
}
