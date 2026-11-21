$Session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
$null = Invoke-WebRequest -Uri 'https://shurufa.sogou.com/windows' -UserAgent $DumplingsBrowserUserAgent -WebSession $Session
$Object1 = Invoke-WebRequest -Uri 'https://shurufa.sogou.com/windows' -UserAgent $DumplingsBrowserUserAgent -WebSession $Session | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//script[contains(., "window.IFE")]').InnerHtml | Get-EmbeddedJson -StartsFrom 'window.IFE = ' | ConvertFrom-Json
$Object3 = $Object2.data.downloadConfig | ConvertFrom-Json

# Version
$this.CurrentState.Version = [regex]::Match($Object3.windows.normal, '(\d+(?:\.\d+)+[a-zA-Z]?)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $Object3.windows.normal
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerUrl = "https://ime.gtimg.com/pc/build/_sogou_pinyin_$($this.CurrentState.RealVersion)_0.exe"
    }
    Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://pinyin.sogou.com/changelog.php' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//*[@class='changebox']/h2[contains(text(), '$($this.CurrentState.Version -creplace 'a$', '')')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(20\d{2}\W+\d{1,2}\W+\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

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
