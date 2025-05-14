function Read-Installer {
  $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
}

function Get-ReleaseNotes {
  try {
    # ReleaseNotesUrl
    # $this.CurrentState.Locale += [ordered]@{
    #   Key   = 'ReleaseNotesUrl'
    #   Value = 'https://support.blastiq.com/hc/sections/360008555173'
    # }

    $Object3 = Invoke-WebRequest -Uri 'https://support.blastiq.com/hc/en-us/sections/360008555173-SHOTPlus-Underground' | ConvertFrom-Html

    $ReleaseNotesUrlNode = $Object3.SelectSingleNode("//ul[contains(@class, 'article-list')]//a[@class='article-list-link' and contains(text(), '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
    if ($ReleaseNotesUrlNode) {
      # ReleaseNotesUrl
      # $this.CurrentState.Locale += [ordered]@{
      #   Key   = 'ReleaseNotesUrl'
      #   Value = $ReleaseNotesUrl = Join-Uri 'https://support.blastiq.com/' ($ReleaseNotesUrlNode.Attributes['href'].Value -replace '/en-us/', '/' -replace '(?<=articles/\d+)-.+')
      # }

      $Object4 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # Remove release notes title
      $Object4.SelectSingleNode("//div[@itemprop='articleBody']//dt[@class='release-notes-title']").Remove()
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object4.SelectSingleNode("//div[@itemprop='articleBody']") | Get-TextContent | Format-Text
      }
    } else {
      $this.Log("No ReleaseNotesUrl and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://downloads.blastiq.com/installers/shotplusug/production/shotplusug.installer.production.exe'
}

$Object1 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
# Hash
$this.CurrentState.Hash = $Object1.Headers.'Content-MD5'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

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

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The hash is unchanged
if ($this.CurrentState.Hash -eq $this.LastState.Hash) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

switch -Regex ($this.Check()) {
  # Case 5: The hash and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 4: The hash has changed, but the version is not
  Default {
    $this.Log('The hash has changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
