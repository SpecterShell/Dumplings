# Apply default function parameters
if ($DumplingsDefaultParameterValues) { $PSDefaultParameterValues = $DumplingsDefaultParameterValues }

# Force stop on error
$ErrorActionPreference = 'Stop'

# Node types that will be ignored during traversing
$IgnoredNodes = @('#whitespace', '#comment')

function ConvertFrom-PropertyList {
  <#
  .SYNOPSIS
    Convert a property list (plist) to hashtable
  .PARAMETER Node
    The property list as a XML node
  .EXAMPLE
    Invoke-RestMethod -Uri 'https://swcatalog.apple.com/content/catalogs/others/index-windows-1.sucatalog' | ConvertFrom-PropertyList
  #>
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The nodes that containing the text')]
    [System.Xml.XmlNode]$Node
  )

  begin {
    $Nodes = [System.Collections.Generic.List[System.Object]]::new()
  }

  process {
    if ($Node.Name -notin $IgnoredNodes) { $Nodes.Add($Node) }
  }

  end {
    foreach ($Node in $Nodes) {
      Write-Verbose -Message "Node type is $($Node.Name)"
      switch ($Node.Name) {
        'dict' {
          $Result = [ordered]@{}
          $Key = $null
          foreach ($ChildNode in $Node.ChildNodes) {
            if ($ChildNode.Name -eq 'Key') {
              $Key = $ChildNode.'#text'
            } elseif ($ChildNode.Name -notin $IgnoredNodes) {
              $Result[$Key] = $ChildNode | ConvertFrom-PropertyList
            }
          }
          Write-Output -InputObject $Result
        }
        'array' { @($Node.ChildNodes | ConvertFrom-PropertyList) }
        'integer' {
          $Result = $null
          if ([Int64]::TryParse($Node.'#text', [ref]$Result)) {
            Write-Output -InputObject $Result
          } elseif ([UInt64]::TryParse($Node.'#text', [ref]$Result)) {
            Write-Output -InputObject $Result
          } else {
            Write-Warning -Message "Failed to parse $($Node.'#text') as signed/unsigned integer, returning as string"
            Write-Output -InputObject $Node.'#text'
          }
        }
        'real' { [double]::Parse($Node.'#text') }
        'string' { if ([string]::IsNullOrEmpty($Node.'#text')) { '' } else { $Node.'#text' } }
        'date' { [datetime]::Parse($Node.'#text') }
        'data' { [System.Convert]::FromBase64String($Node.'#text') }
        'plist' { $Node.ChildNodes | ConvertFrom-PropertyList }
        '#document' { $Node.plist | ConvertFrom-PropertyList }
        Default { throw "Unknown type $($Node.Name)" }
      }
    }
  }
}

Export-ModuleMember -Function ConvertFrom-PropertyList
