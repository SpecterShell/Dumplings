function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

function Get-ReleaseNotes {
  try {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
      [regex]::Match($Object2.SelectSingleNode('./td[@class="td-release-date"]').InnerText, '(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})').Groups[1].Value,
      'M/d/yyyy',
      $null
    ).ToString('yyyy-MM-dd')
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

$Object1 = $Global:DumplingsStorage.AGTEKDownloadPage
$Object2 = $Object1.SelectSingleNode('//tr[contains(./td[@class="td-filename"], "MaterialsSA")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.SelectSingleNode('./td[@class="td-version"]').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.SelectSingleNode('./td[@class="td-button"]/a').Attributes['href'].Value
}

$Object3 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
$ETag = $Object3.Headers.ETag[0]

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
