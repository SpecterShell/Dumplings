# Apply default function parameters
if ($DumplingsDefaultParameterValues) { $PSDefaultParameterValues = $DumplingsDefaultParameterValues }

# Force stop on error
$ErrorActionPreference = 'Stop'

function Read-Varint {
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory)]
    [System.IO.Stream]$Stream,

    [Parameter(Position = 1)]
    [ValidateSet('Int64', 'UInt64', 'Int32', 'UInt32', 'Raw')]
    [string]$OutputType = 'Int64'
  )

  process {
    $Buffer = [System.Collections.Generic.List[byte]]::new()
    do {
      $Byte = $Stream.ReadByte()
      $Buffer.Add($Byte)
    } while ($Byte -band 0b10000000u)

    switch ($OutputType) {
      'UInt64' { $Value = [UInt64]0; continue }
      'Int64' { $Value = [Int64]0; continue }
      'UInt32' { $Value = [UInt32]0; continue }
      'Int32' { $Value = [Int32]0; continue }
      'Raw' { return $Buffer.ToArray() }
      Default { throw "The specified type ${OutputType} is invalid for type Varint" }
    }

    for ($i = $Buffer.Count - 1; $i -ge 0; $i--) {
      $Value = ($Value -shl 7) -bor ($Buffer[$i] -band 0b01111111u)
    }
    return $Value
  }
}

function Read-Fixed64 {
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory)]
    [System.IO.Stream]$Stream,

    [Parameter(Position = 1)]
    [ValidateSet('Int64', 'UInt64', 'Double', 'Raw')]
    [string]$OutputType = 'Int64'
  )

  process {
    $Buffer = [byte[]]::new(8)
    $Stream.Read($Buffer, 0, 8) | Out-Null

    switch ($OutputType) {
      'UInt64' { return [System.BitConverter]::ToUInt64($Buffer, 0) }
      'Int64' { return [System.BitConverter]::ToInt64($Buffer, 0) }
      'Double' { return [System.BitConverter]::ToDouble($Buffer, 0) }
      'Raw' { return $Buffer }
      Default { throw "The specified type ${OutputType} is invalid for type Fixed64" }
    }
  }
}

function Read-Fixed32 {
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory)]
    [System.IO.Stream]$Stream,

    [Parameter(Position = 1)]
    [ValidateSet('Int32', 'UInt32', 'Float', 'Raw')]
    [string]$OutputType = 'Int32'
  )

  process {
    $Buffer = [byte[]]::new(4)
    $Stream.Read($Buffer, 0, 4) | Out-Null

    switch ($OutputType) {
      'UInt32' { return [System.BitConverter]::ToUInt32($Buffer, 0) }
      'Int32' { return [System.BitConverter]::ToInt32($Buffer, 0) }
      'Float' { return [System.BitConverter]::ToSingle($Buffer, 0) }
      'Raw' { return $Buffer }
      Default { throw "The specified type ${OutputType} is invalid for type Fixed32" }
    }
  }
}

function ConvertFrom-ProtoBuf {
  <#
  .SYNOPSIS
    Convert a Protocol Buffer message into a hashtable
  .PARAMETER RawContentStream
    The raw stream of the ProtoBuf message
  .PARAMETER Content
    The raw byte array of the ProtoBuf message
  .PARAMETER Path
    The path to the file containing the ProtoBuf message
  .PARAMETER VarintType
    The expected type of the Varint objects
  .PARAMETER Fixed64Type
    The expected type of the Fixed64 objects
  .PARAMETER Fixed32Type
    The expected type of the Fixed32 objects
  #>
  [OutputType([hashtable])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Stream', Mandatory, HelpMessage = 'The raw stream of the ProtoBuf message')]
    [System.IO.Stream]$RawContentStream,

    [Parameter(Position = 0, ParameterSetName = 'Array', Mandatory, HelpMessage = 'The raw byte array of the ProtoBuf message')]
    [byte[]]$Content,

    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'File', Mandatory, HelpMessage = 'The path to the file containing the ProtoBuf message')]
    [string]$Path,

    [Parameter(Position = 1, HelpMessage = 'The expected type of the Varint objects')]
    [ValidateSet('Int64', 'UInt64', 'Int32', 'UInt32', 'Raw')]
    [string]$VarintType = 'Int64',

    [Parameter(Position = 2, HelpMessage = 'The expected type of the Fixed64 objects')]
    [ValidateSet('Int64', 'UInt64', 'Double', 'Raw')]
    [string]$Fixed64Type = 'Int64',

    [Parameter(Position = 3, HelpMessage = 'The expected type of the Fixed32 objects')]
    [ValidateSet('Int32', 'UInt32', 'Float', 'Raw')]
    [string]$Fixed32Type = 'Int32'
  )

  process {
    # Bare Stream is preferred over StreamReader as StreamReader is buggy on WebResponseContentMemoryStream
    if ($RawContentStream) {
      $StreamType = 'Stream'
      $Stream = $RawContentStream
    } elseif ($Content) {
      $StreamType = 'Array'
      $Stream = [System.IO.MemoryStream]::new($Content)
    } else {
      $StreamType = 'File'
      $Stream = [System.IO.FileStream]::new((Resolve-Path $Path), [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
    }

    $Result = [ordered]@{}
    while ($Stream.ReadByte() -ne -1) {
      $Stream.Position -= 1

      $Metadata = Read-Varint -Stream $Stream -OutputType UInt64
      $FieldNumber = ($Metadata -shr 3).ToString()
      $WireType = $Metadata -band 0b00000111u
      Write-Verbose -Message "Offset: $($Stream.Position);`tField Number: ${FieldNumber};`tWire Type: ${WireType}"

      switch ($WireType) {
        # Varint
        # Possible types include Int64, UInt64, Int32, UInt32, Bool, Enum and ZigZag encodings
        0 { $Value = Read-Varint -Stream $Stream -OutputType $VarintType; continue }
        # Fixed64
        # Possible types include Int64, UInt64, Double and ZigZag encodings
        1 { $Value = Read-Fixed64 -Stream $Stream -OutputType $Fixed64Type; continue }
        # LengthDelimited
        # Possible types include string, bytes, sub message and more
        2 {
          $Length = Read-Varint -Stream $Stream -OutputType $VarintType
          $Buffer = [byte[]]::new($Length)
          $Stream.Read($Buffer, 0, $Length) | Out-Null
          try {
            # Try to decode to string first. If an invalid character occurred, an error will be thrown
            $Value = [System.Text.UTF8Encoding]::new($false, $true).GetString($Buffer)
          } catch {
            try {
              # Try to decode as a sub message
              $SubStream = [System.IO.MemoryStream]::new($Buffer)
              $Value = ConvertFrom-ProtoBuf -RawContentStream $SubStream -VarintType $VarintType -Fixed64Type $Fixed64Type -Fixed32Type $Fixed32Type
            } catch {
              # Pass the byte array if no appropriate type is found for this object
              $Value = $Buffer
            } finally {
              $SubStream.Close()
            }
          }
          continue
        }
        # Fixed32
        # Possible types include Int32, UInt32, Float and ZigZag encodings
        5 { $Value = Read-Fixed32 -Stream $Stream -OutputType $Fixed32Type; continue }
        # StartGroup (3), EndGroup (4) and others
        Default { throw "Unsupported or unknown WireType ${WireType}" }
      }

      # If there are repeated objects (objects with the same field number) at the same level, wrap them into a list
      if ($Result.Contains($FieldNumber)) {
        if ($Result[$FieldNumber] -isnot [System.Collections.Generic.List[System.Object]]) {
          $Result[$FieldNumber] = [System.Collections.Generic.List[System.Object]]::new(@($Result[$FieldNumber]))
        }
        $Result[$FieldNumber].Add($Value)
      } else {
        $Result[$FieldNumber] = $Value
      }
    }

    if ($StreamType -in @('Array', 'File')) { $Stream.Close() }
    return $Result
  }
}

Export-ModuleMember -Function ConvertFrom-ProtoBuf
