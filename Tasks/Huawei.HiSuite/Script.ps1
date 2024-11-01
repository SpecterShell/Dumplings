# Global
$Object1 = Invoke-WebRequest -Uri 'https://consumer.huawei.com/en/support/hisuite/' | ConvertFrom-Html
$Version1 = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/div[6]/div/div/div/div[1]/div[1]/div/div[1]/p/text()[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# China
$Object2 = Invoke-WebRequest -Uri 'https://consumer.huawei.com/cn/support/hisuite/' | ConvertFrom-Html
$Version2 = [regex]::Match(
  $Object2.SelectSingleNode('/html/body/div[5]/div/div/div/div[1]/div[1]/div/div[1]/p/text()[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

$Identical = $true
if ($Version1 -ne $Version2) {
  $this.Log('Inconsistent versions detected', 'Warning')
  $this.Log("Global version: ${Version1}")
  $this.Log("China version: ${Version2}")
  $Identical = $false
}

# Version
$this.CurrentState.Version = $Version = $Version1

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('/html/body/div[6]/div/div/div/div[1]/div[1]/div/div[1]/a').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object2.SelectSingleNode('/html/body/div[5]/div/div/div/div[1]/div[1]/div/div[1]/a').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object1.SelectSingleNode('/html/body/div[6]/div/div/div/div[1]/div[1]/div/div[1]/p/text()[1]').InnerText,
        '(\d{4}\.\d{1,2}\.\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      if ($Global:DumplingsStorage.Contains('HiSuite') -and $Global:DumplingsStorage.HiSuite.Contains($Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.HiSuite.$Version.ReleaseNotesEN
        }

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.HiSuite.$Version.ReleaseNotesCN
        }
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
  ({ $_ -match 'Updated' -and $Identical }) {
    $this.Submit()
  }
}
