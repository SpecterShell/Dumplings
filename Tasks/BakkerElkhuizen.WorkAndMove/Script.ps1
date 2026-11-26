# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = 'https://download.workandmove.com/public/winclient/msi/WorkAndMove.msi'
}

$Result = $this.CheckInstallerUpdates(@{
    Validator   = 'Auto'
    ReadVersion = { param($Path) Read-ProductVersionFromMsi -Path $Path }
  })

if ($Result.NeedsMetadata) {
  try {
    $Object1 = (Invoke-WebRequest -Uri 'https://bakkerelkhuizen.gitbook.io/workandmove/work-and-move-coach/release-notes.md' | Read-ResponseContent) | ConvertFrom-Html
    $Object2 = $Object1.SelectSingleNode('//table/tbody/tr[1]')
    $ReleaseNotesUrl = $Object2.SelectSingleNode('./td[3]/a').Attributes['href'].Value

    # ReleaseTime
    $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object2.SelectSingleNode('./td[2]').InnerText.Trim(), 'dd-MM-yyyy', $null) | Get-Date -Format 'yyyy-MM-dd'

    # ReleaseNotesUrl (en-GB)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-GB'
      Key    = 'ReleaseNotesUrl'
      Value  = $ReleaseNotesUrl -replace '\.md$', ''
    }

    $Object3 = (Invoke-WebRequest -Uri $ReleaseNotesUrl | Read-ResponseContent) | Convert-MarkdownToHtml
    $ReleaseNotesTitleNode = $Object3.SelectSingleNode('./h1')
    $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode[0].NextSibling; $Node; $Node = $Node.NextSibling) {
      if ($Node.Name -ne '#text' -and $Node.Name -ne 'blockquote' -and $Node.InnerText -notmatch '^Release notes of \d{2}-\d{2}-\d{4}$') { $Node }
    }

    # ReleaseNotes (en-GB)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-GB'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$this.CompleteInstallerUpdates($Result)

