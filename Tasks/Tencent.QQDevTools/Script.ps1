$Object1 = Invoke-WebRequest -Uri 'https://q.qq.com/wiki/tools/devtool/stable.html' | ConvertFrom-Html
$ReleaseNotesTitleNode = $Object1.SelectSingleNode('//div[@class="content__default"]/h2[1]')

# Version
$this.CurrentState.Version = $ReleaseNotesTitleNode.SelectSingleNode('./text()').InnerText.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl           = $ReleaseNotesTitleNode.SelectSingleNode('./following::a[contains(@href, ".exe")][1]').Attributes['href'].Value
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = "$($this.CurrentState.Version)_x64"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
        if (-not $Node.SelectSingleNode('.//a[contains(@href, ".exe") or contains(@href, ".dmg")]')) {
          $Node
        }
      }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
