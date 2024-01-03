# International
$Object1 = Invoke-RestMethod -Uri 'https://internal.eassos.com/update/diskgenius/update.php' | ConvertFrom-Ini
# Chinese
$Object2 = Invoke-RestMethod -Uri 'https://www.diskgenius.cn/pro/statistics/update.php' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.version.new

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

$Identical = $true
if ($Object1.version.new -ne $Object2.version.new) {
  $this.Logging('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://engdownload.eassos.cn/DGEngSetup$($Object1.version.new.Replace('.','')).exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = "https://download.eassos.cn/DGSetup$($Object2.version.new.Replace('.','')).exe"
}

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1[$Object1.version.new].releasenote.Split('`|') | Format-Text
}
# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object2[$Object2.version.new].releasenote.Split('`|') | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object3 = Invoke-WebRequest -Uri 'https://www.diskgenius.com/' | ConvertFrom-Html

      if ($Object3.SelectSingleNode('/html/body/div[6]/div[1]/div/div/div[2]/div[1]/span[1]').InnerText.Contains($this.CurrentState.Version)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $Object3.SelectSingleNode('/html/body/div[6]/div[1]/div/div/div[2]/div[1]/span[3]').InnerText,
          'Updated:\s*(.+)'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $Object4 = Invoke-WebRequest -Uri 'https://www.diskgenius.cn/download.php' | ConvertFrom-Html

        if ($Object4.SelectSingleNode('/html/body/div[3]/div/div[4]/h4/text()').InnerText.Contains($this.CurrentState.Version)) {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [regex]::Match(
            $Object4.SelectSingleNode('/html/body/div[3]/div/div[3]/p').InnerText,
            '(\d{4}-\d{1,2}-\d{1,2})'
          ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
        } else {
          $this.Logging("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
        }
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $this.Submit()
  }
}
