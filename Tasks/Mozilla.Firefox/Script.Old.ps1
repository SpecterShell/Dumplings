# The following locales can't be matched by WinGet properly and thus are omitted: ach (Acholi/Acoli), cak (Kaqchikel), ia (Interlingua), lij (Ligurian), sc (Sardinian), sco (Scots), son (Songhai), szl (Silesian), trs (Triqui)
$Locales = @('af', 'an', 'ar', 'ast', 'az', 'be', 'bg', 'bn', 'br', 'bs', 'ca-valencia', 'ca', 'cs', 'cy', 'da', 'de', 'dsb', 'el', 'en-CA', 'en-GB', 'en-US', 'eo', 'es-AR', 'es-CL', 'es-ES', 'es-MX', 'et', 'eu', 'fa', 'ff', 'fi', 'fr', 'fur', 'fy-NL', 'ga-IE', 'gd', 'gl', 'gn', 'gu-IN', 'he', 'hi-IN', 'hr', 'hsb', 'hu', 'hy-AM', 'id', 'is', 'it', 'ja', 'ka', 'kab', 'kk', 'km', 'kn', 'ko', 'lt', 'lv', 'mk', 'mr', 'ms', 'multi', 'my', 'nb-NO', 'ne-NP', 'nl', 'nn-NO', 'oc', 'pa-IN', 'pl', 'pt-BR', 'pt-PT', 'rm', 'ro', 'ru', 'sat', 'si', 'sk', 'sl', 'sq', 'sr', 'sv-SE', 'ta', 'te', 'tg', 'th', 'tl', 'tr', 'uk', 'ur', 'uz', 'vi', 'xh', 'zh-CN', 'zh-TW')
$ArchMap = [ordered]@{
  x86   = 'win32'
  x64   = 'win64'
  arm64 = 'win64-aarch64'
}
$Prefix = 'https://download-installer.cdn.mozilla.net/pub/firefox/releases/'

$Object1 = Invoke-RestMethod -Uri 'https://product-details.mozilla.org/1.0/firefox_versions.json'

# Version
$this.CurrentState.Version = $Version = $Object1.LATEST_FIREFOX_VERSION

$Object2 = [ordered]@{}
Invoke-RestMethod -Uri "${Prefix}${Version}/SHA256SUMS" | Split-LineEndings |
  Where-Object -FilterScript { $_ -match '(win32|win64|win64-aarch64)/' -and $_ -match '\.(exe|msix)$' -and -not $_.Contains('Firefox Installer') } |
  ForEach-Object -Process {
    $Entries = $_.Split('  ')
    $Object2[$Entries[1]] = $Entries[0].ToUpper()
  }

# Installer
foreach ($Arch in $ArchMap.GetEnumerator()) {
  # $this.CurrentState.Installer += [ordered]@{
  #   Architecture    = $Arch.Key
  #   InstallerType   = 'exe'
  #   InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/en-US/Firefox Setup ${Version}.exe"
  #   InstallerSha256 = $Object2["$($Arch.Value)/en-US/Firefox Setup ${Version}.exe"]
  #   ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) en-US)"
  # }
  switch ($Locales) {
    # # en-US is the default locale of the manifests but not listed at the beginning of the list. Add en-US locale explicitly and skip it in this process
    # 'en-US' { continue }
    # MSIX installers (ARM64 not available)
    'multi' {
      $this.CurrentState.Installer += [ordered]@{
        Architecture  = $Arch.Key
        InstallerType = 'msix'
        InstallerUrl  = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.msix"
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
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Azerbaijani (Cyrillic and Latin)
    'az' {
      # $this.CurrentState.Installer += [ordered]@{
      #   InstallerLocale = 'az-Cyrl'
      #   Architecture    = $Arch.Key
      #   InstallerType   = 'exe'
      #   InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
      #   InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
      #   ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      # }
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'az-Latn'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Breton (France)
    'br' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'br-FR'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Catalan (Spain, Valencian)
    'ca-valencia' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'ca-ES-VALENCIA'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Fulah (Adlam and Latin)
    'ff' {
      # $this.CurrentState.Installer += [ordered]@{
      #   InstallerLocale = 'ff-Adlm'
      #   Architecture    = $Arch.Key
      #   InstallerType   = 'exe'
      #   InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
      #   InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
      #   ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      # }
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'ff-Latn'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Friulian (Italy)
    'fur' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'fur-IT'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Scottish Gaelic (United Kingdom)
    'gd' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'gd-GB'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Kabyle (Algeria)
    'kab' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'kab-DZ'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Occitan (France)
    'oc' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'oc-FR'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Santali (Ol Chiki)
    'sat' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'sat-Olck'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Serbian (Cyrillic and Latin)
    'sr' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'sr-Cyrl'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      # $this.CurrentState.Installer += [ordered]@{
      #   InstallerLocale = 'sr-Latn'
      #   Architecture    = $Arch.Key
      #   InstallerType   = 'exe'
      #   InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
      #   InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
      #   ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      # }
      continue
    }
    # Tajik (Tajikistan)
    'tg' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'tg-TJ'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Uzbek (Cyrillic and Latin)
    'uz' {
      # $this.CurrentState.Installer += [ordered]@{
      #   InstallerLocale = 'uz-Cyrl'
      #   Architecture    = $Arch.Key
      #   InstallerType   = 'exe'
      #   InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
      #   InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
      #   ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      # }
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'uz-Latn'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    Default {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = $_
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.LAST_RELEASE_DATE | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = "https://www.mozilla.org/firefox/${Version}/releasenotes/"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # Remove MDN link (not clickable nor viewable in plain text)
      if ($MDNNode = $Object3.SelectSingleNode('//*[@id="note-mdn"]')) { $MDNNode.Remove() }

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object3.SelectSingleNode('//*[@class="c-release-notes"]') | Get-TextContent | Format-Text
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
