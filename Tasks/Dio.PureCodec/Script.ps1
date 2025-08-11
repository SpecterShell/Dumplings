$Object1 = Invoke-WebRequest -Uri 'https://www.wmzhe.com/soft-13163.html' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Object1.SelectSingleNode('//*[@id="app"]/div[3]/div[1]/div[1]/div[2]/div[1]/ul[1]/li[4]/span[2]').InnerText.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="download_group"]/li[9]/dl/dd/a').Attributes['href'].Value -replace '^https://', 'http://'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($this.CurrentState.Version, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'http://diodiy.top/?thread-1.htm' | ConvertFrom-Html
      $Object3 = [System.IO.StringReader]::new($Object2.SelectSingleNode('//div[@isfirst="1"]/pre[contains(., "更新日志")]').InnerText)

      while ($Object3.Peek() -ne -1) {
        $String = $Object3.ReadLine()
        if ($String.StartsWith($this.CurrentState.Version)) {
          break
        }
      }
      if ($Object3.Peek() -ne -1) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while ($Object3.Peek() -ne -1) {
          $String = $Object3.ReadLine()
          if ($String -notmatch '^\d+') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }

      $Object3.Close()
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
