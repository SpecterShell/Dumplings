function Get-ReleaseNotes {
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
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://dl.listary.net/Listary.exe'
}

$Object1 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
# ETag
$this.CurrentState.ETag = $Object1.Headers.ETag[0]

# Case 1: The task is newly created
if ($this.Status.Contains('New')) {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The installer file on the server was not updated
if ($this.CurrentState.ETag -eq $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

$InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
# Version
$this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
# InstallerSha256
$this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

# Case 3: The installer file has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

# Case 4: The installer file on the server was updated, but the hash didn't change
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag was changed, but the hash is the same', 'Info')
  $this.Write()
  return
}

# Case 5: The installer file on the server was updated, and the hash changed, but the version isn't
if ($this.CurrentState.Version -eq $this.LastState.Version) {
  $this.Log('The ETag and the hash were changed, but the version is the same', 'Info')
  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 6: The installer file on the server was updated, and the version is changed
switch -Regex ($this.Check()) {
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
    return
  }
  Default {
    throw 'This region should not be reached'
  }
}
