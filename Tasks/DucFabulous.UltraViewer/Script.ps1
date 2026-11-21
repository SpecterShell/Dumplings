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
  'sr-Latn' = 'sr'
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
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.ultraviewer.net/changelogs.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [datetime]::ParseExact([regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}/\d{1,2}/20\d{2})').Groups[1].Value, 'M/d/yyyy', $null).ToString('yyyy-MM-dd')

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
