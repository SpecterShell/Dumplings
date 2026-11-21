# Installer
$Object1 = Invoke-RestMethod -Uri 'https://education.lego.com/page-data/en-us/downloads/retiredproducts/wedo-2/software/page-data.json'
$Object2 = $Object1.result.pageContext.page.spots.Where({ $_.__dataType -eq 'download' }, 'First')[0].download.software.Where({ $_.entry.software[0].operating_system -eq 'Windows 10' }, 'First')[0].entry.software[0].language[0].entry
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = $Object2.file_url
}
$Version1 = [regex]::Match($Installer.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# China
$Object3 = Invoke-RestMethod -Uri 'https://legoeducation.cn/page-data/zh-cn/downloads/retiredproducts/wedo-2/software/page-data.json'
$Object4 = $Object3.result.pageContext.page.spots.Where({ $_.__dataType -eq 'download' }, 'First')[0].download.software.Where({ $_.entry.software[0].operating_system -eq 'Windows 10' }, 'First')[0].entry.software[0].language[0].entry
$this.CurrentState.Installer += $InstallerCN = [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object4.file_url.Replace('//education.lego.com/', '//legoeducation.cn/')
}
$Version2 = [regex]::Match($InstallerCN.InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($Version1 -ne $Version2) {
  $this.Log("Inconsistent versions: Global: ${Version1}, China: ${Version2}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Version1

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
