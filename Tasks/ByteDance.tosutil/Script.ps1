function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
  # Version
  # Read the version statically from the Go string headers in .rdata. The version
  # string lives next to the "tosutil version" command name in the header table.
  $Layout = Get-PELayout -Path $InstallerFile
  $Section = $Layout.Sections | Where-Object -Property Name -EQ '.rdata'
  $Stream = [System.IO.File]::Open($InstallerFile, 'Open', 'Read', 'ReadWrite')
  try {
    # Anchor: the "tosutil version" command-name string in .rdata
    $AnchorOffset = (Find-BinaryPattern -Stream $Stream -Pattern ([System.Text.Encoding]::ASCII.GetBytes('tosutil version')) -StartOffset $Section.RawOffset -Length $Section.RawSize -Maximum 1)[0]

    # Go string headers are {pointer, length} pairs holding absolute virtual addresses
    $AnchorAddress = [uint64]$Layout.ImageBase + $Section.VirtualAddress + ($AnchorOffset - $Section.RawOffset)
    $HeaderOffset = $null
    foreach ($Candidate in (Find-BinaryPattern -Stream $Stream -Pattern ([System.BitConverter]::GetBytes($AnchorAddress)) -StartOffset $Section.RawOffset -Length $Section.RawSize -Maximum 32)) {
      if ((Read-BinaryInteger -Stream $Stream -Offset ($Candidate + 8) -Size 8 -Signed) -eq 'tosutil version'.Length) { $HeaderOffset = $Candidate; break }
    }
    if ($null -eq $HeaderOffset) { throw 'The tosutil command name string header was not found in the installer' }

    # The version string header follows the anchor header in 16-byte slots
    $Version = $null
    foreach ($Offset in ($HeaderOffset + 16)..($HeaderOffset + 64) | Where-Object { ($_ - $HeaderOffset) % 16 -eq 0 }) {
      $Pointer = Read-BinaryInteger -Stream $Stream -Offset $Offset -Size 8
      $Length = Read-BinaryInteger -Stream $Stream -Offset ($Offset + 8) -Size 8 -Signed
      if ($Length -gt 0 -and $Length -lt 32) {
        $StringOffset = [long]$Pointer - [long]$Layout.ImageBase - $Section.VirtualAddress + $Section.RawOffset
        $Value = [System.Text.Encoding]::ASCII.GetString((Read-BinaryBytes -Stream $Stream -Offset $StringOffset -Count ([int]$Length)))
        if ($Value -match '^v(?<Version>\d+(?:\.\d+)+)$') { $Version = $Matches.Version; break }
      }
    }
    if ([string]::IsNullOrWhiteSpace($Version)) { throw 'The tosutil version string was not found in the installer' }
    $this.CurrentState.Version = $Version
  } finally {
    $Stream.Dispose()
  }
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl    = $InstallerUrl = 'https://tos-tools.tos-cn-beijing.volces.com/windows/tosutil'
  InstallerSha256 = (Invoke-RestMethod -Uri "${InstallerUrl}.sha256sum").Split()[0].ToUpper()
}

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  Read-Installer

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is newly created
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  Read-Installer

  $this.Print()
  $this.Write()
  return
}

# Case 2: The SHA256 is unchanged
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

switch -Regex ($this.Check()) {
  # Case 5: The SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 4: The SHA256 has changed, but the version is not
  Default {
    $this.Log('The SHA256 has changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
