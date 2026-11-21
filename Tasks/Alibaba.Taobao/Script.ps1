function Get-ReleaseNotes {
  try {
    $Object2 = Invoke-WebRequest -Uri 'https://jianghu.taobao.com/detail/47301_28562306' | ConvertFrom-Html

    $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[@id='detailContent']/*[contains(.//strong, 'V$($this.CurrentState.Version)')]")
    if ($ReleaseNotesTitleNode) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(20\d{2}\.\d{1,2}\.\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and -not $Node.SelectSingleNode('.//strong'); $Node = $Node.NextSibling) { $Node }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
      }
    } else {
      $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://tblifecdn.taobao.com/taobaopc/taobao-shop.exe'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator = 'Header'
  HeaderName = 'Content-MD5'
  LegacyState = @{ ValidatorField = 'Hash' }
  ReadVersion = { param($Path) Read-ProductVersionFromExe -Path $Path }
})
if ($Result.NeedsMetadata) { Get-ReleaseNotes }
$this.CompleteInstallerUpdates($Result)
