$LocaleMap = [ordered]@{
  'en-US' = 0x409
  'de-DE' = 0x407
  'es-ES' = 0x40A # 0xC0A
  'fr-FR' = 0x40C
  'it-IT' = 0x410
  'ja-JP' = 0x411
  'ko-KR' = 0x412
  'pt-BR' = 0x416
  'ru-RU' = 0x419
  'zh-CN' = 0x804
  'zh-TW' = 0x404
}
$ArchMap = [ordered]@{
  'x86'   = 'x86'
  'x64'   = 'x64'
  'arm64' = 'ARM64'
}

$Object1 = Invoke-WebRequest -Uri 'https://learn.microsoft.com/en-us/sql/connect/odbc/windows/release-notes-odbc-sql-server-windows' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//div[contains(@class, "content")]/h2[starts-with(text(), "18.")][1]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.SelectSingleNode('./following::text()[contains(., "Version number:")]').InnerText, 'Version number:\s+(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
foreach ($Arch in $ArchMap.Keys) {
  $InstallerUrl = $Object2.SelectSingleNode("./following::a[contains(@href, 'linkid') and contains(text(), '$($ArchMap[$Arch])')][1]").Attributes['href'].Value
  foreach ($Locale in $LocaleMap.Keys) {
    $this.CurrentState.Installer += [ordered]@{
      InstallerLocale = $Locale
      Architecture    = $Arch
      InstallerUrl    = "${InstallerUrl}&clcid=$($LocaleMap[$Locale])"
    }
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('./following::text()[contains(., "Released:")]').InnerText, 'Released:\s+([a-zA-Z]+\W+\d{1,2}\W+\d{4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
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
    # There are too many installers to check, so we defer it to the submit phase to save time
    foreach ($Installer in $this.CurrentState.Installer) {
      $Installer.InstallerUrl = Get-RedirectedUrl -Uri $Installer.InstallerUrl
    }

    $this.Submit()
  }
}
