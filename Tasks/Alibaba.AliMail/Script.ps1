$Object1 = Invoke-RestMethod -Uri 'https://alimei-api.aliyun.com/v1/system/appver' -Method Post -Body @{
  data        = @{
    appname    = 'alimail_standard_redcoast_win'
    appVersion = $this.LastState.Contains('Version') ? $this.LastState.Version : '2.6.0'
  } | ConvertTo-Json -Compress
  accesstoken = ''
}

$this.CurrentState = Invoke-RestMethod -Uri "$($Object1.data.filePath -replace '/$')/$($Object1.data.version)/config/win32/ia32/latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-WebRequest -Uri 'https://help.aliyun.com/document_detail/2530746.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//div[@class='body']/h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{4}\.\d{1,2}\.\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = ($ReleaseNotesNodes | Get-TextContent) -replace '(?m)^\s*\[h2\]' | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
