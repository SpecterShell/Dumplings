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
  InstallerUrl           = "https://engdownload.eassos.cn/DGEngSetup$($Object1.version.new.Replace('.','')).exe"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "DiskGenius V$($this.CurrentState.RealVersion)"
      ProductCode = '{2661F2FA-56A7-415D-8196-C4CB3D3ACFFE}_is1'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale        = 'zh-CN'
  InstallerUrl           = "https://download.eassos.cn/DGSetup$($Object2.version.new.Replace('.','')).exe"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "DiskGenius V$($this.CurrentState.RealVersion)"
      ProductCode = '{6F458B5F-B99E-43E0-8E08-FF9326130BD7}_is1'
    }
  )
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

      if ($Object3.SelectSingleNode('//div[@class="idx-latest"]//div[@class="info"]//div[@class="font"]').InnerText.Contains($this.CurrentState.Version)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $Object3.SelectSingleNode('//div[@class="idx-latest"]//div[@class="info"]//div[@class="font"]').InnerText,
          'Updated:\s*(.+)'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $Object4 = Invoke-WebRequest -Uri 'https://www.diskgenius.cn/download.php' | ConvertFrom-Html

        if ($Object4.SelectSingleNode('//div[@class="smfz"]').InnerText.Contains($this.CurrentState.Version)) {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [regex]::Match(
            $Object4.SelectSingleNode('//div[@class="smfz"]').InnerText,
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
