$Object1 = Invoke-WebRequest -Uri 'https://easyeda.com/page/download' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrlX86 = $Object1.SelectSingleNode('//*[@class="client-wrap"]/table/tr[2]/td[3]/div/span[2]/a').Attributes['href'].Value
}
$VersionX86 = [regex]::Match($InstallerUrlX86, '(\d+\.\d+\.\d+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = $Object1.SelectSingleNode('//*[@class="client-wrap"]/table/tr[2]/td[3]/div/span[1]/a').Attributes['href'].Value
}
$VersionX64 = [regex]::Match($InstallerUrlX64, '(\d+\.\d+\.\d+)').Groups[1].Value

$Identical = $true
if ($VersionX86 -ne $VersionX64) {
  $this.Logging('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $VersionX64

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://easyeda.com/page/update-record' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[contains(@class, 'doc-body-left')]/p[contains(./strong/text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesTimeNode = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::p[1]')
        # ReleaseTime
        $this.CurrentState.ReleaseTime = ($ReleaseNotesTimeNode.InnerText | ConvertTo-HtmlDecodedText).Trim() | Get-Date -Format 'yyyy-MM-dd'

        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTimeNode.NextSibling; -not $Node.SelectSingleNode('./strong'); $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
  ({ $_ -ge 3 -and $Identical }) {
    $this.Submit()
  }
}
