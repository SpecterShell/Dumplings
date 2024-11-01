# Global
$Object1 = Invoke-WebRequest -Uri 'https://www.neat-reader.com/download/start-download?target=windows' | ConvertFrom-Html
$Version1 = $Object1.SelectSingleNode('/html/body/input[2]').Attributes['value'].Value.Trim()

# China
$Object2 = Invoke-WebRequest -Uri 'https://www.neat-reader.cn/downloads/windows' | ConvertFrom-Html
$Version2 = [regex]::Match(
  $Object2.SelectSingleNode('/html/body/div[3]/div/div/p[3]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

$Identical = $true
if ($Version1 -ne $Version2) {
  $this.Log('Inconsistent versions detected', 'Warning')
  $this.Log("Global version: ${Version1}")
  $this.Log("China version: ${Version2}")
  $Identical = $false
}

# Version
$this.CurrentState.Version = $Version1

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://neat-reader-release.oss-cn-hongkong.aliyuncs.com/NeatReader Setup ${Version1}.exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object2.SelectSingleNode('/html/body/div[3]/div/div/div[1]/a[1]').Attributes['href'].Value | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  ({ $_ -match 'Updated' -and $Identical }) {
    $this.Submit()
  }
}
