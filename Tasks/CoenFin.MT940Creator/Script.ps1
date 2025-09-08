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
    $Object3 = Invoke-RestMethod -Uri 'https://coenfin.nl/wp-admin/admin-ajax.php?action=get_wdtable&table_id=2' -Method Post -Body @{
      draw               = '1'
      'columns[0][data]' = '0'
      'columns[0][name]' = 'wdt_ID'
      'columns[1][data]' = '1'
      'columns[1][name]' = 'wdt_created_by'
      'columns[2][data]' = '2'
      'columns[2][name]' = 'wdt_created_at'
      'columns[3][data]' = '3'
      'columns[3][name]' = 'wdt_last_edited_by'
      'columns[4][data]' = '4'
      'columns[4][name]' = 'wdt_last_edited_at'
      'columns[5][data]' = '5'
      'columns[5][name]' = 'versie'
      'columns[6][data]' = '6'
      'columns[6][name]' = 'datum'
      'columns[7][data]' = '7'
      'columns[7][name]' = 'opmerkingen'
      'order[0][column]' = '6'
      'order[0][dir]'    = 'desc'
      start              = '0'
      length             = '5'
      wdtNonce           = ($Object1 | ConvertFrom-Html).SelectSingleNode("//input[@name='wdtNonceFrontendServerSide_2']").Attributes['value'].Value
    }

    $ReleaseNotesObject = $Object3.data.Where({ $_[5] -eq $this.CurrentState.Version }, 'First')
    if ($ReleaseNotesObject) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $ReleaseNotesObject[0][6] | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (nl-NL)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'nl-NL'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesObject[0][7] | ConvertFrom-Html | Get-TextContent | Format-Text
      }
    } else {
      $this.Log("No ReleaseTime and ReleaseNotes (nl-NL) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$Object1 = Invoke-WebRequest -Uri 'https://coenfin.nl/mt940-creator/'

$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and -not $_.href.Contains('Server') } catch {} }, 'First')[0].href
}

$Object2 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
$ETag = $Object2.Headers.ETag[0]

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
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (Global)", 'Info')
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
  default {
    $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
