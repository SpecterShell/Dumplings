$Object1 = Invoke-WebRequest -Uri 'https://www.autodesk.com/products/design-review/download' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//*[@data-cmp-hook-accordion="summaryRoot" and contains(., "Version x64")]/following-sibling::*[@data-cmp-hook-accordion="panel"]')

# Installer
$Node = $Object2.SelectSingleNode('.//a[contains(@href, ".exe") and contains(@href, "_en_")]')
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en'
  Architecture    = 'x64'
  InstallerUrl    = $Node.Attributes['href'].Value
}
$VersionEN = [regex]::Match($Node.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

$Node = $Object2.SelectSingleNode('.//a[contains(@href, ".exe") and contains(@href, "_deu_")]')
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'de'
  Architecture    = 'x64'
  InstallerUrl    = $Node.Attributes['href'].Value
}
$VersionDE = [regex]::Match($Node.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

$Node = $Object2.SelectSingleNode('.//a[contains(@href, ".exe") and contains(@href, "_esp_")]')
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'es'
  Architecture    = 'x64'
  InstallerUrl    = $Node.Attributes['href'].Value
}
$VersionES = [regex]::Match($Node.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

$Node = $Object2.SelectSingleNode('.//a[contains(@href, ".exe") and contains(@href, "_fra_")]')
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'fr'
  Architecture    = 'x64'
  InstallerUrl    = $Object2.SelectSingleNode('.//a[contains(@href, ".exe") and contains(@href, "_fra_")]').Attributes['href'].Value
}
$VersionFR = [regex]::Match($Node.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

$Node = $Object2.SelectSingleNode('.//a[contains(@href, ".exe") and contains(@href, "_ita_")]')
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'it'
  Architecture    = 'x64'
  InstallerUrl    = $Node.Attributes['href'].Value
}
$VersionIT = [regex]::Match($Node.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

$Node = $Object2.SelectSingleNode('.//a[contains(@href, ".exe") and contains(@href, "_jpn_")]')
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ja'
  Architecture    = 'x64'
  InstallerUrl    = $Node.Attributes['href'].Value
}
$VersionJA = [regex]::Match($Node.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

$Node = $Object2.SelectSingleNode('.//a[contains(@href, ".exe") and contains(@href, "_kor_")]')
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ko'
  Architecture    = 'x64'
  InstallerUrl    = $Node.Attributes['href'].Value
}
$VersionKO = [regex]::Match($Node.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

$Node = $Object2.SelectSingleNode('.//a[contains(@href, ".exe") and contains(@href, "_plk_")]')
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'pl'
  Architecture    = 'x64'
  InstallerUrl    = $Node.Attributes['href'].Value
}
$VersionPL = [regex]::Match($Node.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

$Node = $Object2.SelectSingleNode('.//a[contains(@href, ".exe") and contains(@href, "_pt-BR_")]')
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'pt-BR'
  Architecture    = 'x64'
  InstallerUrl    = $Node.Attributes['href'].Value
}
$VersionPTBR = [regex]::Match($Node.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

$Node = $Object2.SelectSingleNode('.//a[contains(@href, ".exe") and contains(@href, "_rus_")]')
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ru'
  Architecture    = 'x64'
  InstallerUrl    = $Node.Attributes['href'].Value
}
$VersionRU = [regex]::Match($Node.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

$Node = $Object2.SelectSingleNode('.//a[contains(@href, ".exe") and contains(@href, "_chs_")]')
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x64'
  InstallerUrl    = $Node.Attributes['href'].Value
}
$VersionZHCN = [regex]::Match($Node.InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

if (@(@($VersionEN, $VersionDE, $VersionES, $VersionFR, $VersionIT, $VersionJA, $VersionKO, $VersionPL, $VersionPTBR, $VersionRU, $VersionZHCN) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: en: ${VersionEN}, de: ${VersionDE}, es: ${VersionES}, fr: ${VersionFR}, it: ${VersionIT}, ja: ${VersionJA}, ko: ${VersionKO}, pl: ${VersionPL}, pt-BR: ${VersionPTBR}, ru: ${VersionRU}, zh-CN: ${VersionZHCN}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionEN

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $Object2 = 7z.exe e -y -so $InstallerFile 'db-bootstrap.json' | ConvertFrom-Json
      $InstallerFileExtracted = New-TempFolder
      7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $Object2.FileInfo[0].File | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted $Object2.FileInfo[0].File
      $Object3 = 7z.exe e -y -so $InstallerFile2 'setup.xml' | ConvertFrom-Xml
      # ProductCode
      $Installer['ProductCode'] = $Object3.Bundle.Identity.UPI2

      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
