$Object1 = Invoke-WebRequest -Uri 'https://wubi.sogou.com/' | ConvertFrom-Html

$PseudoInstallerUrl = $Object1.SelectSingleNode('//*[@id="bannerCon_new"]/a').Attributes['href'].Value

# Version
$this.CurrentState.Version = [regex]::Match($PseudoInstallerUrl, '.+?/pc/dl/gzindex/.+?/sogou_wubi_(.+?)\.exe').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object1.SelectSingleNode('//*[@id="bannerCon_new"]/p[2]').InnerText, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $PseudoInstallerUrl

    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerUrl = "https://ime.sogoucdn.com/sogou_wubi_$($this.CurrentState.RealVersion).exe"
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://wubi.sogou.com/log.php' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@class='log_con']/h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::*') | Get-TextContent | Format-Text
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
