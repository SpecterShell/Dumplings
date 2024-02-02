$Object1 = Invoke-RestMethod -Uri 'https://imehd.baidu.com/nodeApi/getTplDetail?token=4b5b978065af11ee8148d75d569ec4b6'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.data.content.updataLogVersion, 'V([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.content.updataLogDown
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match(
  $Object1.data.content.updataLogTime,
  '(\d{4}\.\d{1,2}\.\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://shurufa.baidu.com/update' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[@class='update-item-tit' and contains(./span[@class='update-item-tit-font']/text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::div[@class="update-item-con"]'); -not $Node.Attributes.Contains('class') -or -not $Node.Attributes['class'].Value.Contains('update-item-tit'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
