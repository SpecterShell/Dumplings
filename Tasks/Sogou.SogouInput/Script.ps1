$Object1 = (Invoke-WebRequest -Uri 'https://pinyin.sogou.com/windows/').Content

$Match = [regex]::Match($Object1, 'window\.location\.href\s*=\s*"(.+?/pc/dl/gzindex/.+?/sogou_pinyin_(.+?)\.exe.+?)"')

# Version
$this.CurrentState.Version = $Match.Groups[2].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = $Object1 | ConvertFrom-Html

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($Object2.SelectSingleNode('//*[@id="banner0_text3"]').InnerText, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $Match.Groups[1].Value
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerUrl = "https://ime.gtimg.com/pc/build/_sogou_pinyin_[Release]_$($this.CurrentState.RealVersion)_0.exe"
    }
    Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://pinyin.sogou.com/changelog.php' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//*[@class='changebox']/h2[contains(text(), '$($this.CurrentState.Version -creplace 'a$', '')')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
