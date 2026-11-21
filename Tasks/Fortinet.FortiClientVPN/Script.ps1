# Fortinet ships the free VPN-only client only as an evergreen online installer
# (FortiClientVPNInstaller.exe, the 'FCT Light Installer'). The file carries no
# version in its URL, so changes are tracked with the Last-Modified validator and
# the version comes from the downloaded executable. The bootstrapper itself
# downloads the real payload over Fortinet's proprietary FCP protocol
# (POST /fdsupdate, port 80, DES-encrypted objects with the $Global:DumplingsSecret.FortiClientKey key): an
# FDNI server-list query, an FECT image-table query, then a SelectiveUpdate FIMG
# download of the offline installer. Replaying that exchange here confirms that
# the image table matches the bootstrapper version and yields the nested MSI that
# carries the authoritative ProductCode, UpgradeCode, and product version.

function Get-Crc32 {
  param([byte[]]$Bytes)

  $Table = [uint32[]]::new(256)
  for ($Index = 0; $Index -lt 256; $Index++) {
    $Value = [uint64]$Index
    for ($Bit = 0; $Bit -lt 8; $Bit++) {
      $Value = (($Value -band 1) -eq 1) ? (($Value -shr 1) -bxor [uint64]0xEDB88320u) : ($Value -shr 1)
    }
    $Table[$Index] = [uint32]$Value
  }

  $Crc = [uint64]0xFFFFFFFFu
  foreach ($Byte in $Bytes) {
    $Crc = $Table[(($Crc -bxor [uint64]$Byte) -band 0xFF)] -bxor ($Crc -shr 8)
  }
  return [BitConverter]::ToUInt32([BitConverter]::GetBytes([uint32]($Crc -bxor [uint64]0xFFFFFFFFu)), 0)
}

function Copy-ByteArraySegment {
  param([byte[]]$Bytes, [int]$Offset, [int]$Count)

  $Segment = [byte[]]::new($Count)
  [Array]::Copy($Bytes, $Offset, $Segment, 0, $Count)
  return $Segment
}

function ConvertTo-FcpPackage {
  # Reproduces FCP_create_package_hdr and FCP_pack_obj from the bootstrapper:
  # a 64-byte 'PUTF' package header and a 128-byte object header ('FCPC' /
  # 'FCP Command') whose payload is DES-CBC encrypted with the $Global:DumplingsSecret.FortiClientKey key.
  param([byte[]]$Plaintext)

  $Key = [Text.Encoding]::ASCII.GetBytes($Global:DumplingsSecret.FortiClientKey)
  $Des = [System.Security.Cryptography.DES]::Create()
  $Des.Key = $Key
  $Des.IV = $Key
  $Ciphertext = $Des.CreateEncryptor().TransformFinalBlock($Plaintext, 0, $Plaintext.Length)
  $Des.Dispose()

  $Header = [byte[]]::new(128)
  [Text.Encoding]::ASCII.GetBytes('FCPC').CopyTo($Header, 0)
  [Text.Encoding]::ASCII.GetBytes('FCP Command'.PadRight(20)).CopyTo($Header, 4)
  [Text.Encoding]::ASCII.GetBytes(('0000000000' + [DateTime]::UtcNow.ToString('yyMMddHHmm')).PadRight(20)).CopyTo($Header, 24)
  [BitConverter]::GetBytes([uint32]0x10000).CopyTo($Header, 44)
  [BitConverter]::GetBytes([uint32]$Ciphertext.Length).CopyTo($Header, 48)
  [BitConverter]::GetBytes([uint32]128).CopyTo($Header, 52)
  [BitConverter]::GetBytes([uint32](Get-Crc32 $Plaintext)).CopyTo($Header, 120)
  [BitConverter]::GetBytes([uint32]0x4E643148).CopyTo($Header, 124)
  [BitConverter]::GetBytes([uint32](Get-Crc32 $Header)).CopyTo($Header, 124)

  $Package = [byte[]]::new(64 + 128 + $Ciphertext.Length)
  [Text.Encoding]::ASCII.GetBytes('PUTF').CopyTo($Package, 0)
  [Text.Encoding]::ASCII.GetBytes('02050000').CopyTo($Package, 4)
  [BitConverter]::GetBytes([uint32]1).CopyTo($Package, 12)
  [BitConverter]::GetBytes([uint32](128 + $Ciphertext.Length)).CopyTo($Package, 16)
  [BitConverter]::GetBytes([uint32]64).CopyTo($Package, 20)
  [Text.Encoding]::ASCII.GetBytes([DateTime]::UtcNow.ToString('yyyyMMddHHmm')).CopyTo($Package, 24)
  [BitConverter]::GetBytes([uint32]0x53673142).CopyTo($Package, 60)
  [BitConverter]::GetBytes([uint32](Get-Crc32 (Copy-ByteArraySegment -Bytes $Package -Offset 0 -Count 64))).CopyTo($Package, 60)
  $Header.CopyTo($Package, 64)
  $Ciphertext.CopyTo($Package, 192)
  return $Package
}

function Get-FortiClientServerList {
  # Asks the default update server for the FDNI distribution server list.
  $Objects = @(Invoke-FcpRequest -Server 'forticlient.fortinet.net' -Command 'Update' -DataItem '00000000FDNI00000000000000000000')
  $List = @($Objects.Where({ $_.Name -eq 'FDNI' }))
  if (-not $List) { throw 'The FortiGuard FDNI response did not contain the server list object.' }

  return @([Text.Encoding]::ASCII.GetString($List[0].Data).Split("`r`n") | ForEach-Object {
    ($_ -split '\|' | Where-Object { $_.StartsWith('Address=') }) -replace '^Address=', ''
  } | ForEach-Object { ($_ -split ':')[0] } | Where-Object { $_ })
}

function Invoke-FcpRequest {
  # Sends one FCP request to a FortiGuard distribution server over plain HTTP
  # on port 80 (the bootstrapper maps the server-list port 443 to port 80) and
  # returns the decrypted response objects. -PayloadPath stores the largest
  # object instead of keeping its bytes in memory.
  param([string]$Server, [string]$Command, [string]$DataItem, [string]$PayloadPath)

  $Uid = (Get-Random -Minimum 1000000000 -Maximum 9999999999).ToString()
  $Uid2 = -join (1..16 | ForEach-Object { '{0:x2}' -f (Get-Random -Maximum 256) }).ToUpper()
  $Plaintext = [Text.Encoding]::ASCII.GetBytes(
    (@(
      'Protocol=2.0'
      "Command=$Command"
      'Firmware=FCT100-FW-7.4.3-6006'
      "SerialNumber=FCT800$Uid"
      'Persistent=false'
      'AcceptDelta=1'
      "Uid=$Uid"
      "DataItem=$DataItem"
      "Uid2=$Uid2"
      "Host=$Server"
      'Language=en'
    ) -join '|') + "`r`n`r`n")

  $Payload = ConvertTo-FcpPackage $Plaintext
  # The exchange is a hand-framed POST over a raw socket: the distribution
  # servers truncate or reject requests shaped by System.Net.Http (Invoke-
  # WebRequest and HttpClient both fail), never use a system proxy, and close
  # the connection after one response.
  $Request = [Text.Encoding]::ASCII.GetBytes(
    "POST /fdsupdate HTTP/1.1`r`n" +
    'User-Agent: Mozilla/4.0 (compatible; FCT 7.4.3; Windows NT 5.1)' + "`r`n" +
    "Host: $Server`r`n" +
    "Cache-Control: no-cache`r`n" +
    "Content-Length: $($Payload.Length)`r`n`r`n")

  $Client = [System.Net.Sockets.TcpClient]::new()
  $Body = [System.IO.MemoryStream]::new()
  try {
    $Connect = $Client.ConnectAsync($Server, 80)
    if (-not $Connect.Wait(15000)) { throw "Timed out connecting to the FortiGuard server $Server." }
    $Stream = $Client.GetStream()
    $Stream.WriteTimeout = 30000
    $Stream.ReadTimeout = 600000
    $Stream.Write($Request, 0, $Request.Length)
    $Stream.Write($Payload, 0, $Payload.Length)

    $Buffer = [byte[]]::new(1MB)
    while (($Read = $Stream.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
      $Body.Write($Buffer, 0, $Read)
    }
  } finally {
    $Client.Dispose()
  }

  $Bytes = $Body.ToArray()
  $Body.Dispose()

  $BodyOffset = 4 + [Text.Encoding]::ASCII.GetString($Bytes, 0, [Math]::Min(1024, $Bytes.Length)).IndexOf("`r`n`r`n", [StringComparison]::Ordinal)
  if ($BodyOffset -lt 4 -or -not [Text.Encoding]::ASCII.GetString($Bytes, 0, $BodyOffset).StartsWith('HTTP/1.1 200')) {
    throw "The FortiGuard server $Server did not return a successful HTTP response."
  }
  $StoredCrc = [BitConverter]::ToUInt32($Bytes, $BodyOffset + 60)
  [BitConverter]::GetBytes([uint32]0x53673142).CopyTo($Bytes, $BodyOffset + 60)
  if ((Get-Crc32 (Copy-ByteArraySegment -Bytes $Bytes -Offset $BodyOffset -Count 64)) -ne $StoredCrc) {
    throw "The FCP response from $Server failed the package checksum."
  }

  $ObjectCount = [BitConverter]::ToUInt32($Bytes, $BodyOffset + 12)
  $Offset = $BodyOffset + 64
  $Objects = @()
  for ($Number = 1; $Number -le $ObjectCount; $Number++) {
    $Name = [Text.Encoding]::ASCII.GetString($Bytes, $Offset, 4).TrimEnd([char]0)
    $Flags = [BitConverter]::ToUInt32($Bytes, $Offset + 44)
    $Length = [BitConverter]::ToUInt32($Bytes, $Offset + 48)
    $HeaderSize = [BitConverter]::ToUInt32($Bytes, $Offset + 52)
    $DataOffset = $Offset + $HeaderSize
    $StoredObjectCrc = [BitConverter]::ToUInt32($Bytes, $Offset + 120)
    $FileName = [Text.Encoding]::ASCII.GetString($Bytes, $Offset + 76, 28).TrimEnd([char]0)

    $Data = Copy-ByteArraySegment -Bytes $Bytes -Offset $DataOffset -Count $Length

    # Decrypt raw cipher blocks without removing the padding, then inflate.
    # The stored checksum covers the transformed bytes before padding removal.
    # The server picks encryption, compression, or both per response, so the
    # checksum is skipped only for the large image payload.
    if (($Flags -band 0x10000) -ne 0) {
      $Des = [System.Security.Cryptography.DES]::Create()
      $Des.Key = [Text.Encoding]::ASCII.GetBytes($Global:DumplingsSecret.FortiClientKey)
      $Des.IV = [Text.Encoding]::ASCII.GetBytes($Global:DumplingsSecret.FortiClientKey)
      $Des.Padding = [System.Security.Cryptography.PaddingMode]::None
      $Data = $Des.CreateDecryptor().TransformFinalBlock($Data, 0, $Data.Length)
      $Des.Dispose()
    }
    if (($Flags -band 1) -ne 0) {
      $Compressed = Copy-ByteArraySegment -Bytes $Data -Offset 2 -Count ($Data.Length - 2)
      $Zlib = [System.IO.Compression.DeflateStream]::new(
        [System.IO.MemoryStream]::new($Compressed),
        [System.IO.Compression.CompressionMode]::Decompress)
      $Output = [System.IO.MemoryStream]::new()
      $Zlib.CopyTo($Output)
      $Zlib.Dispose()
      $Data = $Output.ToArray()
    }

    if ($Name -eq 'FIMG' -and $PayloadPath) {
      # The image payload is large; checksum it by parsing instead.
      [IO.File]::WriteAllBytes($PayloadPath, $Data)
      $Data = $null
    } elseif ($Name -ne 'FCPR' -and (Get-Crc32 $Data) -ne $StoredObjectCrc) {
      throw "The FCP response object $Name failed its checksum."
    }

    if ($null -ne $Data -and ($Flags -band 0x10000) -ne 0) {
      $PadLength = [int]$Data[-1]
      if ($PadLength -ge 1 -and $PadLength -le 8 -and $PadLength -le $Data.Length) {
        $Data = Copy-ByteArraySegment -Bytes $Data -Offset 0 -Count ($Data.Length - $PadLength)
      }
    }

    $Objects += [ordered]@{ Name = $Name; FileName = $FileName; Data = $Data }
    $Offset = $DataOffset + $Length
  }
  return $Objects
}

function Get-FortiClientVpnImageInfo {
  # Resolves the current VPN-only Windows image the way the bootstrapper does:
  # ask for the FDNI server list, then fetch the FECT image table from a
  # distribution node and select the x64 FIMG row of this branch.
  param([string]$Version)

  $Branch = $Version.Split('.')[0..2] -join '.'
  foreach ($Node in (Get-FortiClientServerList)) {
    $Objects = @(Invoke-FcpRequest -Server $Node -Command 'Update' -DataItem '01000000FECT00000000000000000000')
    $Table = @($Objects.Where({ $_.Name -eq 'FECT' }))
    if (-not $Table) { continue }

    # Bootstrapper selection: an 'L' row of the VPNWIN64 platform whose image id
    # belongs to the 07004000 branch. LIMG rows carry the language transform.
    $Image = $null
    foreach ($Line in [Text.Encoding]::ASCII.GetString($Table[0].Data).Split("`n")) {
      if ($Line -match '^L FCT VPNWIN64 FIMG (?<Version>\d+(?:\.\d+){2}) (?<Id>07004000\S+)' -and $Matches.Version -eq $Branch) {
        $Image = @{ Version = $Matches.Version; Id = $Matches.Id }
      }
    }
    if ($Image) {
      return @{ Version = [string]$Image.Version; Id = [string]$Image.Id }
    }
  }
  throw "The FortiGuard image table does not list a VPNWIN64 FIMG image for version $Branch."
}

function Save-FortiClientImage {
  param([string]$ImageId, [string]$Path)

  $Errors = @()
  foreach ($Node in (Get-FortiClientServerList)) {
    try {
      $Objects = @(Invoke-FcpRequest -Server $Node -Command 'SelectiveUpdate' -DataItem $ImageId -PayloadPath $Path)
      $Response = @($Objects.Where({ $_.Name -eq 'FCPR' }))
      if ($Response -and -not [Text.Encoding]::ASCII.GetString($Response[0].Data).Contains('Response=200')) {
        throw "the server answered: $([Text.Encoding]::ASCII.GetString($Response[0].Data).Trim())"
      }
      if ((Test-Path -LiteralPath $Path) -and (Get-Item -LiteralPath $Path).Length -gt 100MB) { return }
    } catch {
      $Errors += "FortiGuard server ${Node}: $_"
      Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    }
  }
  throw "No FortiGuard distribution server delivered the FIMG image. $($Errors -join ' ')"
}

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://filestore.fortinet.com/forticlient/downloads/FortiClientVPNInstaller.exe'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator   = 'LastModified'
  ReadVersion = { param($Path) Read-FileVersionFromExe -Path $Path }
})

if ($Result.NeedsMetadata) {
  $Image = Get-FortiClientVpnImageInfo -Version $this.CurrentState.Version
  if ($Image.Version -ne ($this.CurrentState.Version.Split('.')[0..2] -join '.')) {
    throw "The FortiGuard image table serves FortiClient VPN $($Image.Version), which does not match the installer version $($this.CurrentState.Version)."
  }

  $ExtractedPath = New-TempFolder
  try {
    $SetupPath = Join-Path $ExtractedPath 'FortiClientSetup.exe'
    Save-FortiClientImage -ImageId $Image.Id -Path $SetupPath

    # The payload is a native stub followed by the raw MSI database. Carve the
    # database from its CFB signature and parse it once for the manifest identity.
    # Latin-1 maps every byte to one character, so a string search over it finds
    # the signature at the exact byte offset.
    $Latin1 = [Text.Encoding]::GetEncoding(28591)
    $SetupText = [IO.File]::ReadAllText($SetupPath, $Latin1)
    $Signature = -join [char[]](0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1)
    $Offset = $SetupText.IndexOf($Signature, [StringComparison]::Ordinal)
    if ($Offset -lt 0) { throw 'The FortiClient offline installer does not contain an embedded MSI database.' }
    $MsiPath = Join-Path $ExtractedPath 'FortiClientVPN.msi'
    [IO.File]::WriteAllBytes($MsiPath, $Latin1.GetBytes($SetupText.Substring($Offset)))
    $SetupText = $null

    $MsiInfo = Get-MsiInstallerInfo -Path $MsiPath
    $this.CurrentState.RealVersion = $MsiInfo.DisplayVersion
    if ($this.CurrentState.RealVersion -ne $this.CurrentState.Version) {
      throw "The nested MSI reports version $($this.CurrentState.RealVersion) while the installer reports $($this.CurrentState.Version)."
    }

    $Installer = $this.CurrentState.Installer[0]
    $Installer.ProductCode = $MsiInfo.ProductCode
    $Installer.AppsAndFeaturesEntries = @(
      [ordered]@{
        UpgradeCode   = $MsiInfo.UpgradeCode
        InstallerType = $MsiInfo.InstallerType
      }
    )
  } finally {
    Remove-Item -LiteralPath $ExtractedPath -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$this.CompleteInstallerUpdates($Result)
