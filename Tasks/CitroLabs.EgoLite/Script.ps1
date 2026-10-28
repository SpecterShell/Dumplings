function Read-Installer {
  $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
}

$Object1 = Invoke-RestMethod -Uri 'https://update.citrolabs.ai/service/update2' -Method Post -Body (
  @{
    request = @{
      apps         = @(
        @{
          appid       = '{712b23bf-e734-4038-be42-d5736b6d9570}'
          updatecheck = @{ sameversionupdate = $true }
          version     = '0.0.0.0'
        }
      )
      arch         = 'x64'
      os           = @{
        arch     = 'x86_64'
        platform = 'Windows'
        version  = '10.0.22000'
      }
      protocol     = '4.0'
      acceptformat = 'crx3,download,puff,run,xz,zucc'
    }
  } | ConvertTo-Json -Depth 5 -Compress
) -ContentType 'application/json' | Get-EmbeddedJson -StartsFrom ")]}'" | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.response.apps[0].updatecheck.nextversion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://cdn.ego.app/setup/windows/x64/egoliteSetup.exe'
}

$ETag = (Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head).Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

  Read-Installer

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
