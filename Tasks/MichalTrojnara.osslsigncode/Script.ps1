###############################################################################
# NOTES: Uses Tasks/PixPin.PixPin.Beta/Script.ps1 as the template.
###############################################################################

# Fetch the latest assets URL.
# NOTES: It seems the runner provides built-in GitHub CLI. We can use it to bypass API Rate Limits.
$LatestInfo = gh api '/repos/mtrojnar/osslsigncode/releases' --jq '.[0]' | ConvertFrom-Json

# Version
$this.CurrentState.Version = $LatestInfo.tag_name

# Installer
$LatestAsset = $LatestInfo.assets | Where-Object -Property name -Like '*windows*'
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $LatestAsset.browser_download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # Release Time
      $this.CurrentState.ReleaseTime = $LatestAsset.updated_at.toUniversalTime()

      # Release Notes (en-US)
      $ReleaseNotesObject = $LatestInfo.body | Convert-MarkdownToHtml
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
      }

      # Release Notes Url
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $LatestInfo.html_url
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
