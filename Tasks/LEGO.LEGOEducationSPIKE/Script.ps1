# Global
$Object1 = Invoke-RestMethod -Uri 'https://education.lego.com/page-data/en-us/downloads/spike-app/software/page-data.json'
$Object2 = $Object1.result.pageContext.page.spots.Where({ $_.__dataType -eq 'downloadSection' }, 'First')[0].items.Where({ $_.software.device -eq 'Windows 10' }, 'First')[0].software.language.Where({ $_.__downloadType -eq 'file' }, 'First')[0]
$Version1 = $Object2.version

# China
$Object3 = Invoke-RestMethod -Uri 'https://legoeducation.cn/page-data/zh-cn/downloads/spike-app/software/page-data.json'
$Object4 = $Object3.result.pageContext.page.spots.Where({ $_.__dataType -eq 'downloadSection' }, 'First')[0].items.Where({ $_.software.device -eq 'Windows 10' }, 'First')[0].software.language.Where({ $_.__downloadType -eq 'file' }, 'First')[0]
$Version2 = $Object4.version

if ($Version1 -ne $Version2) {
  $this.Log("Global version: ${Version1}")
  $this.Log("China version: ${Version2}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Version1

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.url
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = Join-Uri 'https://legoeducation.cn/' $Object4.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = ($Object1.result.pageContext.page.spots.Where({ $_.__dataType -eq 'downloadSection' }, 'First')[0].appReleaseNotes | ConvertFrom-Markdown).Html | Get-EmbeddedLinks | Where-Object -FilterScript { $_.outerHTML.Contains($this.CurrentState.Version) } | Select-Object -First 1 -ExpandProperty href
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
