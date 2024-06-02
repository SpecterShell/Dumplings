# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://dl.listary.net/Listary.exe'
}
$Object1 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head -Headers @{'If-Modified-Since' = $this.LastState['LastModified'] } -SkipHttpErrorCheck
if ($Object1.StatusCode -eq 304) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

# InstallerSha256
$this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

# Version
$this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe

try {
  $ReleaseNotesUrl = 'https://help.listary.com/changelog'
  $ReleaseNotesUrlCN = 'https://help.listary.com/zh-Hans/changelog'
  $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

  $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//header/following-sibling::h3[contains(., '$($this.CurrentState.Version)')]")
  if ($ReleaseNotesTitleNode) {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '\(([a-zA-Z]+\W+\d{1,2}\W+\d{4})\)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
    }

    # ReleaseNotes (en-US)
    $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
    }

    # ReleaseNotesUrl
    $this.CurrentState.Locale += [ordered]@{
      Key   = 'ReleaseNotesUrl'
      Value = $ReleaseNotesUrl + '#' + ($ReleaseNotesTitleNode.InnerText.ToLower() -creplace '[^a-zA-Z0-9 ]+' -creplace '\s+', '-').Trim('-')
    }
    # ReleaseNotesUrl (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotesUrl'
      Value  = $ReleaseNotesUrlCN + '#' + ($ReleaseNotesTitleNode.InnerText.ToLower() -creplace '[^a-zA-Z0-9 ]+' -creplace '\s+', '-').Trim('-')
    }
  } else {
    $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    # ReleaseNotesUrl
    $this.CurrentState.Locale += [ordered]@{
      Key   = 'ReleaseNotesUrl'
      Value = $ReleaseNotesUrl
    }
    # ReleaseNotesUrl (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Key   = 'ReleaseNotesUrl'
      Value = $ReleaseNotesUrlCN
    }
  }
} catch {
  $_ | Out-Host
  $this.Log($_, 'Warning')
  # ReleaseNotesUrl
  $this.CurrentState.Locale += [ordered]@{
    Key   = 'ReleaseNotesUrl'
    Value = $ReleaseNotesUrl
  }
  # ReleaseNotesUrl (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Key   = 'ReleaseNotesUrl'
    Value = $ReleaseNotesUrlCN
  }
}

$this.Print()
$this.Write()
if (-not $this.Check().Contains('New') -and $this.LastState.Installer[0].InstallerSha256 -ne $this.CurrentState.Installer[0].InstallerSha256) {
  $this.Message()
  $this.Submit()
}
