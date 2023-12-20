$Content = (Invoke-WebRequest -Uri 'https://pinyin.sogou.com/windows/').Content

$Match = [regex]::Match($Content, 'window\.location\.href\s*=\s*"(.+?/pc/dl/gzindex/.+?/sogou_pinyin_(.+?)\.exe.+?)"')

# Version
$this.CurrentState.Version = $Match.Groups[2].Value

$Object1 = $Content | ConvertFrom-Html

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match($Object1.SelectSingleNode('//*[@id="banner0_text3"]').InnerText, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $Match.Groups[1].Value

    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerUrl    = "https://ime.sogoucdn.com/sogou_pinyin_$($this.CurrentState.RealVersion).exe"
      InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    }

    $Object2 = Invoke-WebRequest -Uri 'https://pinyin.sogou.com/changelog.php' | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@class='changebox']/h2[contains(text(), '$($this.CurrentState.Version.Insert(2, '.'))')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (zh-CN)
        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
