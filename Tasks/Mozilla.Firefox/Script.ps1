$Locales = @('ach', 'af', 'an', 'ar', 'ast', 'az', 'be', 'bg', 'bn', 'br', 'bs', 'ca-valencia', 'ca', 'cak', 'cs', 'cy', 'da', 'de', 'dsb', 'el', 'en-CA', 'en-GB', 'en-US', 'eo', 'es-AR', 'es-CL', 'es-ES', 'es-MX', 'et', 'eu', 'fa', 'ff', 'fi', 'fr', 'fur', 'fy-NL', 'ga-IE', 'gd', 'gl', 'gn', 'gu-IN', 'he', 'hi-IN', 'hr', 'hsb', 'hu', 'hy-AM', 'ia', 'id', 'is', 'it', 'ja', 'ka', 'kab', 'kk', 'km', 'kn', 'ko', 'lij', 'lt', 'lv', 'mk', 'mr', 'ms', 'multi', 'my', 'nb-NO', 'ne-NP', 'nl', 'nn-NO', 'oc', 'pa-IN', 'pl', 'pt-BR', 'pt-PT', 'rm', 'ro', 'ru', 'sat', 'sc', 'sco', 'si', 'sk', 'sl', 'son', 'sq', 'sr', 'sv-SE', 'szl', 'ta', 'te', 'tg', 'th', 'tl', 'tr', 'trs', 'uk', 'ur', 'uz', 'vi', 'xh', 'zh-CN', 'zh-TW')
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
  $this.CurrentState.Installer += [ordered]@{
    Architecture    = $Arch.Key
    InstallerType   = 'exe'
    InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/en-US/Firefox Setup ${Version}.exe"
    InstallerSha256 = $Object2["$($Arch.Value)/en-US/Firefox Setup ${Version}.exe"]
    ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) en-US)"
  }
  switch ($Locales) {
    # en-US is the default locale of the manifests but not listed at the beginning of the list. Add en-US locale explicitly and skip it in this process
    'en-US' { continue }
    # MSIX installers (ARM64 not available)
    'multi' {
      if ($Arch.Key -ne 'arm64') {
        $this.CurrentState.Installer += [ordered]@{
          Architecture  = $Arch.Key
          InstallerType = 'msix'
          InstallerUrl  = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.msix"
        }
      }
      continue
    }
    # The language-only locales ast, gd and sr are not supported by WinGet client
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
    'sr' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'sr-Cyrl'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'sr-Latn'
        Architecture    = $Arch.Key
        InstallerType   = 'exe'
        InstallerUrl    = "${Prefix}${Version}/$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"
        InstallerSha256 = $Object2["$($Arch.Value)/${_}/Firefox Setup ${Version}.exe"]
        ProductCode     = "Mozilla Firefox ${Version} ($($Arch.Key) ${_})"
      }
      continue
    }
    # Replace ca-valencia with ca-ES
    'ca-valencia' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'ca-ES'
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

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.LAST_RELEASE_DATE | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl = "https://www.mozilla.org/firefox/${Version}/releasenotes/"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # Remove MDN link (not clickable nor viewable in plain text)
      if ($MDNNode = $Object3.SelectSingleNode('//*[@id="note-mdn"]')) { $MDNNode.Remove() }

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotes = $Object3.SelectSingleNode('//*[@class="c-release-notes"]') | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    # Too many installers...
    $this.Message(@"
Mozilla.Firefox

Version: ${Version}
ReleaseDate: $($this.CurrentState.ReleaseTime)
ReleaseNotes (en-US):
${ReleaseNotes}
ReleaseNotesUrl (*):
${ReleaseNotesUrl}
"@)
  }
  'Updated' {
    $this.Submit()
  }
}
