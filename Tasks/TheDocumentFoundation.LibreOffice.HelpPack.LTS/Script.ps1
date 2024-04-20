# The following locales can't be matched by WinGet properly and thus are omitted: sid
$Locales = @('am', 'ar', 'ast', 'bg', 'bn-IN', 'bn', 'bo', 'bs', 'ca-valencia', 'ca', 'cs', 'da', 'de', 'dsb', 'dz', 'el', 'en-GB', 'en-US', 'en-ZA', 'eo', 'es', 'et', 'eu', 'fi', 'fr', 'gl', 'gu', 'he', 'hi', 'hr', 'hsb', 'hu', 'id', 'is', 'it', 'ja', 'ka', 'km', 'ko', 'lo', 'lt', 'lv', 'mk', 'nb', 'ne', 'nl', 'nn', 'om', 'pl', 'pt-BR', 'pt', 'ro', 'ru', 'si', 'sk', 'sl', 'sq', 'sv', 'ta', 'tg', 'tr', 'ug', 'uk', 'vi', 'zh-CN', 'zh-TW')
$ArchMap = [ordered]@{
  x86   = 'x86'
  x64   = 'x86_64'
  arm64 = 'aarch64'
}

# Version
$Object1 = Invoke-WebRequest -Uri 'https://www.libreoffice.org/download/download-libreoffice/' | ConvertFrom-Html
$ShortVersion = $Object1.SelectNodes('//span[@class="dl_version_number"]').InnerText | Sort-Object -Property { $_ -replace '\d+', { $_.Value.PadLeft(20) } } -Top 1

$Object2 = Invoke-WebRequest -Uri 'https://downloadarchive.documentfoundation.org/libreoffice/old/?C=N;O=D;V=1;F=0'
$this.CurrentState.Version = ($Object2.Links.href -match "^$([regex]::Escape($ShortVersion))[\d\.]+/$")[0].TrimEnd('/')

# Installer
$Prefix = 'https://downloadarchive.documentfoundation.org/libreoffice/old/'
foreach ($Arch in $ArchMap.GetEnumerator()) {
  switch ($Locales) {
    # Handle special language cases
    # Asturian (Spain)
    'ast' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'ast-ES'
        Architecture    = $Arch.Key
        InstallerUrl    = "${Prefix}$($this.CurrentState.Version)/win/$($Arch.Value)/LibreOffice_$($this.CurrentState.Version)_Win_$($Arch.Value.Replace('_', '-'))_helppack_${_}.msi"
      }
      continue
    }
    # Tibetan (China)
    'bo' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'bo-CN'
        Architecture    = $Arch.Key
        InstallerUrl    = "${Prefix}$($this.CurrentState.Version)/win/$($Arch.Value)/LibreOffice_$($this.CurrentState.Version)_Win_$($Arch.Value.Replace('_', '-'))_helppack_${_}.msi"
      }
      continue
    }
    # Catalan (Spain, Valencian)
    'ca-valencia' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'ca-ES-VALENCIA'
        Architecture    = $Arch.Key
        InstallerUrl    = "${Prefix}$($this.CurrentState.Version)/win/$($Arch.Value)/LibreOffice_$($this.CurrentState.Version)_Win_$($Arch.Value.Replace('_', '-'))_helppack_${_}.msi"
      }
      continue
    }
    # Tajik (Tajikistan)
    'tg' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'tg-TJ'
        Architecture    = $Arch.Key
        InstallerUrl    = "${Prefix}$($this.CurrentState.Version)/win/$($Arch.Value)/LibreOffice_$($this.CurrentState.Version)_Win_$($Arch.Value.Replace('_', '-'))_helppack_${_}.msi"
      }
      continue
    }
    # Uyghur (China)
    'ug' {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = 'ug-CN'
        Architecture    = $Arch.Key
        InstallerUrl    = "${Prefix}$($this.CurrentState.Version)/win/$($Arch.Value)/LibreOffice_$($this.CurrentState.Version)_Win_$($Arch.Value.Replace('_', '-'))_helppack_${_}.msi"
      }
      continue
    }
    Default {
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = $_
        Architecture    = $Arch.Key
        InstallerUrl    = "${Prefix}$($this.CurrentState.Version)/win/$($Arch.Value)/LibreOffice_$($this.CurrentState.Version)_Win_$($Arch.Value.Replace('_', '-'))_helppack_${_}.msi"
      }
      continue
    }
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
