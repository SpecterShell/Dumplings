$Object1 = Invoke-WebRequest -Uri 'https://www.diskgenius.com/download.php' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match($Object1.SelectSingleNode('//div[@class="fz1"]/span[1]').InnerText, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl           = "https://download2.eassos.com/DGEngSetup$($this.CurrentState.Version.Replace('.','')).exe"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "DiskGenius V$($this.CurrentState.RealVersion)"
      ProductCode = '{2661F2FA-56A7-415D-8196-C4CB3D3ACFFE}_is1'
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object1.SelectSingleNode('//div[@class="fz1"]').InnerText,
        '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      if ($Object1.SelectSingleNode('//div[@class="ver"]').InnerText.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.SelectSingleNode('//ul[@class="list"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.diskgenius.cn/download.php' | ConvertFrom-Html

      if ($Object2.SelectSingleNode('//ul[contains(@class, "logmenu")]/li[contains(@class, "cur")]').InnerText.Contains($this.CurrentState.Version.Split('.')[0..2] -join '.')) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectSingleNode('//div[@class="descrip"]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
