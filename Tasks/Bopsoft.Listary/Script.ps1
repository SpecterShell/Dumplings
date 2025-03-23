function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

function Get-ReleaseNotes {
  try {
    # ReleaseNotesUrl
    $this.CurrentState.Locale += [ordered]@{
      Key   = 'ReleaseNotesUrl'
      Value = $ReleaseNotesUrl = 'https://help.listary.com/changelog'
    }
    # ReleaseNotesUrl (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotesUrl'
      Value  = $ReleaseNotesUrlCN = 'https://help.listary.com/zh-Hans/changelog'
    }

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
      $this.Log("No ReleaseTime, ReleaseNotes (en-US), ReleaseNotesUrl and ReleaseNotesUrl (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://dl.listary.net/Listary.exe'
}

$Object1 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
$ETag = $Object1.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The ETag is unchanged
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

# Case 4: The ETag has changed, but the SHA256 is not
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag has changed, but the SHA256 is not', 'Info')

  # ETag
  $this.CurrentState.ETag = $this.LastState.ETag + $ETag

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)

switch -Regex ($this.Check()) {
  # Case 6: The ETag, the SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: The ETag and the SHA256 have changed, but the version is not
  Default {
    $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
