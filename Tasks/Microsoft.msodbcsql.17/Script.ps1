$LocaleMap = [ordered]@{
  'en-US' = 0x409
  'de-DE' = 0x407
  'es-ES' = 0xC0A
  'fr-FR' = 0x40C
  'it-IT' = 0x410
  'ja-JP' = 0x411
  'ko-KR' = 0x412
  'pt-BR' = 0x416
  'ru-RU' = 0x419
  'zh-CN' = 0x804
  'zh-TW' = 0x404
}

$Object1 = Invoke-WebRequest -Uri 'https://learn.microsoft.com/en-us/sql/connect/odbc/windows/release-notes-odbc-sql-server-windows' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//div[contains(@class, "content")]/h2[starts-with(text(), "17.")][1]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.SelectSingleNode('./following::text()[contains(., "Version number:")]').InnerText, 'Version number:\s+(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$InstallerUrl = Get-RedirectedUrl -Uri $Object2.SelectSingleNode('./following::a[contains(@href, "linkid") and contains(text(), "x64")][1]').Attributes['href'].Value
foreach ($Locale in $LocaleMap.Keys) {
  foreach ($Arch in @('x86', 'x64')) {
    $Installer = [ordered]@{}

    if ($Locale -ne 'en-US') {
      $Installer['InstallerLocale'] = $Locale
    }

    $Installer['Architecture'] = $Arch

    if ($Arch -eq 'x64') {
      $Installer['InstallerUrl'] = $InstallerUrl -replace "$($LocaleMap.Values -join '|')", $LocaleMap[$Locale] -replace "$($LocaleMap.Keys -join '|')", $Locale
    } else {
      $Installer['InstallerUrl'] = $InstallerUrl -replace "$($LocaleMap.Values -join '|')", $LocaleMap[$Locale] -replace "$($LocaleMap.Keys -join '|')", $Locale -replace 'x64|amd64', $Arch
    }

    $this.CurrentState.Installer += $Installer
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
    $this.Submit()
  }
}
