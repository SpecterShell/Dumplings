$Object1 = (Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=19502').Content | Get-EmbeddedJson -StartsFrom 'window.__DLCDetails__=' | ConvertFrom-Json
# x86
$Object2 = $Object1.dlcDetailsView.downloadFile.Where({ $_.name.EndsWith('.msi') -and $_.name -match 'DatabaseProviders' -and $_.name -match 'x86' }, 'First')[0]
# x64
$Object3 = $Object1.dlcDetailsView.downloadFile.Where({ $_.name.EndsWith('.msi') -and $_.name -match 'DatabaseProviders' -and $_.name -match 'x64' }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en-US'
  Architecture    = 'x86'
  InstallerUrl    = $Object2.url
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en-US'
  Architecture    = 'x64'
  InstallerUrl    = $Object3.url
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.datePublished | Get-Date | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    foreach ($Locale in @('de-DE', 'es-ES', 'fr-FR', 'it-IT', 'ja-JP', 'ko-KR', 'pt-BR', 'ru-RU', 'zh-CN', 'zh-TW')) {
      $Object4 = (Invoke-WebRequest -Uri "https://www.microsoft.com/$Locale/download/details.aspx?id=19502").Content | Get-EmbeddedJson -StartsFrom 'window.__DLCDetails__=' | ConvertFrom-Json

      # Installer
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = $Locale
        Architecture    = 'x86'
        InstallerUrl    = $Object4.dlcDetailsView.downloadFile.Where({ $_.name.EndsWith('.msi') -and $_.name -match 'DatabaseProviders' -and $_.name -match 'x86' }, 'First')[0].url
      }
      $this.CurrentState.Installer += [ordered]@{
        InstallerLocale = $Locale
        Architecture    = 'x64'
        InstallerUrl    = $Object4.dlcDetailsView.downloadFile.Where({ $_.name.EndsWith('.msi') -and $_.name -match 'DatabaseProviders' -and $_.name -match 'x64' }, 'First')[0].url
      }
    }

    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
