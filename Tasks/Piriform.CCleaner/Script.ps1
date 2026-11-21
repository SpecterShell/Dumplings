# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://bits.avcdn.net/productfamily_CCLEANER7/insttype_FREE/platform_WIN/installertype_FULL/build_RELEASE'
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'Auto'
    ReadVersion = { param($Path) Read-ProductVersionFromExe -Path $Path }
  })

if ($Result.NeedsMetadata) {
  try {
    $Object1 = Invoke-WebRequest -Uri 'https://www.ccleaner.com/ccleaner/version-history' | ConvertFrom-Html

    $Object1.SelectNodes('//h6').ForEach({ $_.InnerHtml = $_.InnerHtml -replace '(?<=^|\.)0+(?=\d)' })
    $ReleaseNotesTitleNode = $Object1.SelectSingleNode("//h6[contains(., 'v$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
    if ($ReleaseNotesTitleNode) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}\W+[a-zA-Z]+\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h6' -and -not $Node.InnerText.Contains('download CCleaner for Android and iOS'); $Node = $Node.NextSibling) { $Node }
      # ReleaseNotes (en-US)
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

$this.CompleteInstallerUpdates($Result)
