function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  $InstallerFileExtracted = New-TempFolder
  Expand-Archive -Path $InstallerFile -DestinationPath $InstallerFileExtracted -Force
  $InstallerFile2 = Join-Path $InstallerFileExtracted 'piicrawler.exe' -Resolve
  # Version
  # Read the version statically from the string literals in the .rdata section (YY.MMDD.build)
  # The version is a compile-time constant and is the only string of this shape in the section
  $Section = (Get-PELayout -Path $InstallerFile2).Sections | Where-Object -Property Name -EQ '.rdata'
  $Stream = [System.IO.File]::OpenRead($InstallerFile2)
  try {
    $Stream.Position = $Section.RawOffset
    $Buffer = [byte[]]::new($Section.RawSize)
    $Read = 0
    while ($Read -lt $Buffer.Length) { $Read += $Stream.Read($Buffer, $Read, $Buffer.Length - $Read) }
  } finally {
    $Stream.Dispose()
  }
  $VersionCandidates = @([regex]::Matches([System.Text.Encoding]::ASCII.GetString($Buffer), '(?<![\d.])\d{2}\.\d{4}\.\d{4}(?![\d.])').Value | Sort-Object -Unique)
  if ($VersionCandidates.Count -ne 1) { throw "Failed to extract the version from the installer: $($VersionCandidates.Count) candidates found" }
  $this.CurrentState.Version = $VersionCandidates[0]
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  Remove-Item -Path $InstallerFile, $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://downloads.eligian.com/piicrawler-cli-windows-signed.zip'
}

$Object1 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
$ETag = $Object1.Headers.ETag[0]

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
