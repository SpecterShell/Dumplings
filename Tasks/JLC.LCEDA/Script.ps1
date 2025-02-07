$Object1 = Invoke-WebRequest -Uri 'https://lceda.cn/page/download' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = $Object1.SelectSingleNode('//*[@class="client-wrap"]/table/tr[2]/td[3]/div/span[2]/a').Attributes['href'].Value
}
$VersionX86 = [regex]::Match($InstallerUrlX86, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = $Object1.SelectSingleNode('//*[@class="client-wrap"]/table/tr[2]/td[3]/div/span[1]/a').Attributes['href'].Value
}
$VersionX64 = [regex]::Match($InstallerUrlX64, '-(\d+\.\d+\.\d+)[-.]').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://lceda.cn/page/update-record' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[contains(@class, 'doc-body-left')]/p[contains(./strong/text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[1]')
        # ReleaseTime
        $this.CurrentState.ReleaseTime = ($ReleaseNotesTimeNode.InnerText | ConvertTo-HtmlDecodedText).Trim() | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTimeNode.NextSibling; $Node -and -not $Node.SelectSingleNode('./strong'); $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
