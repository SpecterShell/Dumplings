$LocaleMap = [ordered]@{
  'en'      = 'en'
  'es'      = 'es'
  'fa'      = 'ir'
  'fr'      = 'fr'
  'id'      = 'id'
  'it'      = 'it'
  'ja'      = 'jp'
  'ko'      = 'kr'
  'pl'      = 'pl'
  'pt'      = 'pt'
  'ro'      = 'ro'
  'ru'      = 'ru'
  'sr'      = 'sr'
  'th'      = 'th'
  'tr'      = 'tr'
  'vi'      = 'vi'
  'zh-Hans' = 'cn'
  'zh-Hant' = 'tw'
}

$Prefix = 'https://dl2.ultraviewer.net/'
$Object1 = Invoke-WebRequest -Uri 'https://www.ultraviewer.net/en/download.html'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Download UltraViewer - (\d+(?:\.\d+){2})').Groups[1].Value

# Installer
$InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
foreach ($Locale in $LocaleMap.Keys) {
  $this.CurrentState.Installer += [ordered]@{
    InstallerLocale = $Locale
    InstallerUrl    = Join-Uri $Prefix $InstallerUrl.Replace('en', $LocaleMap[$Locale])
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
