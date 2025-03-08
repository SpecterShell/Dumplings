$Object1 = Invoke-WebRequest -Uri 'https://www.altova.com/thankyou?ProductCode=UM&EditionCode=E&InstallerType=Product&Lang=en&OperatingSystem=win32'

# Installer
$InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en'
  Architecture    = 'x86'
  InstallerUrl    = $InstallerUrl
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en'
  Architecture    = 'x64'
  InstallerUrl    = $InstallerUrl -replace '\.exe$', '_x64.exe'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'de'
  Architecture    = 'x86'
  InstallerUrl    = $InstallerUrl -replace '/en/', '/de/' -replace '\.exe$', '_DE.exe'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'de'
  Architecture    = 'x64'
  InstallerUrl    = $InstallerUrl -replace '/en/', '/de/' -replace '\.exe$', '_x64_DE.exe'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'es'
  Architecture    = 'x86'
  InstallerUrl    = $InstallerUrl -replace '/en/', '/es/' -replace '\.exe$', '_ES.exe'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'es'
  Architecture    = 'x64'
  InstallerUrl    = $InstallerUrl -replace '/en/', '/es/' -replace '\.exe$', '_x64_ES.exe'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'fr'
  Architecture    = 'x86'
  InstallerUrl    = $InstallerUrl -replace '/en/', '/fr/' -replace '\.exe$', '_FR.exe'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'fr'
  Architecture    = 'x64'
  InstallerUrl    = $InstallerUrl -replace '/en/', '/fr/' -replace '\.exe$', '_x64_FR.exe'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ja'
  Architecture    = 'x86'
  InstallerUrl    = $InstallerUrl -replace '/en/', '/jp/' -replace '\.exe$', '_JP.exe'
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'ja'
  Architecture    = 'x64'
  InstallerUrl    = $InstallerUrl -replace '/en/', '/jp/' -replace '\.exe$', '_x64_JP.exe'
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '/v(\d+(r\d+)?(sp\d+)?)/').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.Log("Processing $($Installer.InstallerLocale) $($Installer.Architecture) installer", 'Verbose')

      $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = New-TempFolder
      7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFileExtracted}" $InstallerFile '*.cab' | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted '*.cab' | Get-Item -Force | Select-Object -First 1
      $InstallerFile2Extracted = New-TempFolder
      7z.exe e -aoa -ba -bd -y -o"${InstallerFile2Extracted}" $InstallerFile2 '*.msi' | Out-Host
      $InstallerFile3 = Join-Path $InstallerFile2Extracted '*.msi' | Get-Item -Force | Select-Object -First 1

      # InstallerSha256
      $Installer.InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerFile3 | Read-ProductVersionFromMsi
      # ProductCode
      $Installer.ProductCode = $InstallerFile3 | Read-ProductCodeFromMsi
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.altova.com/releasenotes/getnotes' -Method Post -Body @{
        category = 'desktop'
        product  = 'UModel'
        version  = $this.CurrentState.Version
      } | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes('/table/tbody/tr').ForEach({ "[$($_.SelectSingleNode('./td[@class="component"]').InnerText)] $($_.SelectSingleNode('./td[@class="summary"]').InnerText)" }) | Format-Text
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
