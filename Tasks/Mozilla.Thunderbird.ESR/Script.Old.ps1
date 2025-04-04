# The following locales can't be matched by WinGet properly and thus are omitted: cak (Kaqchikel)
$Locales = @('af', 'ar', 'ast', 'be', 'bg', 'br', 'ca', 'cs', 'cy', 'da', 'de', 'dsb', 'el', 'en-CA', 'en-GB', 'en-US', 'es-AR', 'es-ES', 'es-MX', 'et', 'eu', 'fi', 'fr', 'fy-NL', 'ga-IE', 'gd', 'gl', 'he', 'hr', 'hsb', 'hu', 'hy-AM', 'id', 'is', 'it', 'ja', 'ka', 'kab', 'kk', 'ko', 'lt', 'lv', 'ms', 'multi', 'nb-NO', 'nl', 'nn-NO', 'pa-IN', 'pl', 'pt-BR', 'pt-PT', 'rm', 'ro', 'ru', 'sk', 'sl', 'sq', 'sr', 'sv-SE', 'th', 'tr', 'uk', 'uz', 'vi', 'zh-CN', 'zh-TW')
$ArchMap = [ordered]@{
  x86 = 'win32'
  x64 = 'win64'
  # arm64 = 'win64-aarch64'
}
$Prefix = 'https://download-installer.cdn.mozilla.net/pub/thunderbird/releases/'

$Object1 = Invoke-RestMethod -Uri 'https://product-details.mozilla.org/1.0/thunderbird_versions.json'

# Version
$this.CurrentState.Version = $Version = $Object1.THUNDERBIRD_ESR.Replace('esr', '')

$Object2 = [ordered]@{}
Invoke-RestMethod -Uri "${Prefix}${Version}esr/SHA256SUMS" | Split-LineEndings |
  Where-Object -FilterScript { $_ -match '(win32|win64|win64-aarch64)/' -and $_ -match '\.(exe|msix)$' -and -not $_.Contains('Thunderbird Installer') } |
  ForEach-Object -Process {
    $Entries = $_.Split('  ')
    $Object2[$Entries[1]] = $Entries[0].ToUpper()
  }

# Installer
foreach ($Arch in $ArchMap.GetEnumerator()) {
  # $this.CurrentState.Installer += [ordered]@{
  #   Architecture    = $Arch.Key
  #   InstallerType   = 'exe'
  #   InstallerUrl    = "${Prefix}${Version}esr/$($Arch.Value)/en-US/Thunderbird Setup ${Version}esr.exe"
  #   InstallerSha256 = $Object2["$($Arch.Value)/en-US/Thunderbird Setup ${Version}esr.exe"]
  #   ProductCode     = "Mozilla Thunderbird ${Version} ($($Arch.Key) en-US)"
  # }
  switch ($Locales) {
    # # en-US is the default locale of the manifests but not listed at the beginning of the list. Add en-US locale explicitly and skip it in this process
    # 'en-US' { continue }
    # MSIX installers (ARM64 not available)
    'multi' {
      if ($Arch.Key -ne 'arm64') {
        $this.CurrentState.Installer += [ordered]@{
          Architecture  = $Arch.Key
          InstallerType = 'msix'
          InstallerUrl  = "${Prefix}${Version}esr/$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.msix"
        }
      }
      continue
    }
    # Handle special language cases
    # Asturian (Spain)
    'ast' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'ast-ES'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}esr/$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"]
        ProductCode     = "Mozilla Thunderbird ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Breton (France)
    'br' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'br-FR'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}esr/$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"]
        ProductCode     = "Mozilla Thunderbird ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Scottish Gaelic (United Kingdom)
    'gd' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'gd-GB'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}esr/$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"]
        ProductCode     = "Mozilla Thunderbird ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Kabyle (Algeria)
    'kab' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'kab-DZ'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}esr/$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"]
        ProductCode     = "Mozilla Thunderbird ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Serbian (Cyrillic and Latin)
    'sr' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'sr-Cyrl'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}esr/$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"]
        ProductCode     = "Mozilla Thunderbird ${Version} ($($Arch.Key) ${_})"
      }
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'sr-Latn'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}esr/$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"]
        ProductCode     = "Mozilla Thunderbird ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Uzbek (Cyrillic and Latin)
    'uz' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'uz-Cyrl'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}esr/$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"]
        ProductCode     = "Mozilla Thunderbird ${Version} ($($Arch.Key) ${_})"
      }
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'uz-Latn'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}esr/$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"]
        ProductCode     = "Mozilla Thunderbird ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    Default {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = $_
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}esr/$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Thunderbird Setup ${Version}esr.exe"]
        ProductCode     = "Mozilla Thunderbird ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = "https://www.thunderbird.net/thunderbird/${Version}esr/releasenotes/"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-RestMethod -Uri 'https://product-details.mozilla.org/1.0/thunderbird.json'

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.releases."thunderbird-${Version}esr".date | Get-Date -Format 'yyyy-MM-dd'

    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object4 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # Remove headers
      $Object4.SelectNodes('/html/body/main/section[contains(./div/@class, "release-notes-container")]//div[@class="see-all-releases"]').ForEach({ $_.Remove() })

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object4.SelectSingleNode('/html/body/main/section[contains(./div/@class, "release-notes-container")]') | Get-TextContent | Format-Text
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
