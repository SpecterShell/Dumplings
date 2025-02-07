$Object1 = Invoke-RestMethod -Uri 'https://svc-drcn.developer.huawei.com/community/servlet/consumer/cn/documentPortal/getDocumentById' -Method Post -Body (
  [ordered]@{
    objectId    = 'quickapp-ide-download-0000001101172926'
    version     = ''
    catalogName = 'Tools-Library'
    language    = 'cn'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'
$Object2 = $Object1.value.content.content | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl = $Object2.SelectSingleNode('//a[contains(@href, ".exe") and contains(@href, "Win64")]').Attributes['href'].Value | ConvertTo-HtmlDecodedText
}

# Version
$this.CurrentState.Version = [regex]::Match(
  $InstallerUrl,
  'V(\d+\.\d+\.\d+)'
).Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-RestMethod -Uri 'https://svc-drcn.developer.huawei.com/community/servlet/consumer/cn/documentPortal/getDocumentById' -Method Post -Body (
        [ordered]@{
          objectId    = 'ide-version-description-0000001101335948'
          version     = ''
          catalogName = 'Tools-Guides'
          language    = 'cn'
        } | ConvertTo-Json -Compress
      ) -ContentType 'application/json'
      $Object4 = $Object3.value.content.content | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object4.SelectSingleNode("/html/body/div/div[contains(./h4, '$($this.CurrentState.Version)版本更新说明')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{4}\.\d{1,2}\.\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.InnerText.Contains('版本更新说明'); $Node = $Node.NextSibling) { $Node }
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
