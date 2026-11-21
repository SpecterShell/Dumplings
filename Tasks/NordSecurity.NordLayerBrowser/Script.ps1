function Read-Installer {
  $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
}

function Get-ReleaseNotes {
  try {
    $Object2 = Invoke-WebRequest -Uri 'https://help.nordlayer.com/docs/nordbrowser-windows' | ConvertFrom-Html

    $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(., '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
    if ($ReleaseNotesTitleNode) {
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -notin @('h1', 'h2'); $Node = $Node.NextSibling) {
        if ($Node.InnerText -match '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})') {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
        } else {
          $Node
        }
      }
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

$Object1 = Invoke-RestMethod -Uri 'https://nlbupdates.nordlayer.com/nordbrowser/service/update2/json' -Method Post -Body (
  @{
    request = @{
      apps     = @(
        @{
          appid       = '{9d9d773d-3f56-433b-baa3-9f960c4bf35b}'
          updatecheck = @{ sameversionupdate = $true }
          version     = '0.0.0.0'
        }
      )
      arch     = 'x64'
      os       = @{
        arch     = 'x86_64'
        platform = 'Windows'
        version  = '10.0.22000'
      }
      protocol = '4.0'
    }
  } | ConvertTo-Json -Depth 5 -Compress
) -ContentType 'application/json' | Get-EmbeddedJson -StartsFrom ")]}'" | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.response.apps[0].updatecheck.nextversion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://downloads.nordlayer.com/nordbrowser/latest/NordBrowserSetup.exe'
}

$ETag = (Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head).Headers.ETag[0]

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

# Case 2: The version has changed
switch -Regex ($this.Check()) {
  'Updated|Rollbacked' {
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
}

# Case 3: The version and the ETag have not changed
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

# Case 4: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

# Case 5: The ETag has changed, but the hash is not
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag has changed, but the SHA256 is not', 'Info')

  # ETag
  $this.CurrentState.ETag = $this.LastState.ETag + $ETag

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)

# Case 6: Both the ETag and the hash have changed
$this.Log('The ETag and the hash have changed', 'Info')
$this.Config.IgnorePRCheck = $true
$this.Print()
$this.Write()
$this.Message()
$this.Submit()
