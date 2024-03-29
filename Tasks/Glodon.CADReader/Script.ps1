$Object1 = Invoke-RestMethod -Uri 'https://cadreader.glodon.com/query/update/cadpc?clientVersion=3.4.3.12&cadpcClientBits=32'

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl           = $Object1.data.url
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "CADReader v$($this.CurrentState.Version)"
      ProductCode = '{F820B3E7-90F4-4420-8C49-3B0107740927}_is1'
    }
  )
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl = $Object1.data.pageUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes('/html/body/div/p[2]/following-sibling::p[count(.|/html/body/div/br/preceding-sibling::p)=count(/html/body/div/br/preceding-sibling::p)]').InnerText | Format-Text
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
