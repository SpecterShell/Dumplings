# Global
$Object1 = Invoke-RestMethod -Uri 'https://education.lego.com/page-data/en-us/downloads/mindstorms-ev3/software/page-data.json'
$Object2 = $Object1.result.pageContext.page.spots.Where({ $_.__dataType -eq 'download' }, 'First')[0].download.software.Where({ $_.entry.software[0].operating_system -eq 'Windows 10' }, 'First')[0].entry.software[0].language[0].entry
$Version1 = $Object2.version

# China
$Object3 = Invoke-RestMethod -Uri 'https://legoeducation.cn/page-data/zh-cn/downloads/mindstorms-ev3/software/page-data.json'
$Object4 = $Object3.result.pageContext.page.spots.Where({ $_.__dataType -eq 'download' }, 'First')[0].download.software.Where({ $_.entry.software[0].operating_system -eq 'Windows 10' }, 'First')[0].entry.software[0].language[0].entry
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
  InstallerUrl = $Object2.file_url
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object4.file_url
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
