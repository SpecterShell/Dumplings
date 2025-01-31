function Get-YamlSchemaValue {
  <#
  .SYNOPSIS
    Get the target definition of a reference in the given YAML schema
  .PARAMETER InputObject
    The YAML schema object
  .PARAMETER Ref
    The reference string
  .PARAMETER Path
    The path to the root directory if the reference source is a relative file path
  .EXAMPLE
    Get-YamlSchemaValue -InputObject $Schema -Ref '#/definitions/Person'
  .EXAMPLE
    Get-YamlSchemaValue -InputObject $Schema -Ref 'https://example.com/schema.json#/definitions/Person'
  .EXAMPLE
    Get-YamlSchemaValue -InputObject $Schema -Ref 'schema.json#/definitions/Person' -Path 'C:\path\to\root\directory'
  #>
  param (
    [Parameter(Position = 0, ValueFromPipeline, HelpMessage = 'The YAML schema object')]
    $InputObject,

    [Parameter(Position = 1, Mandatory, HelpMessage = 'The reference string')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Ref,

    [Parameter(Position = 2, HelpMessage = 'The path to the root directory if the reference source is a relative file path')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Path
  )

  process {
    $RefSource, $RefPath = $Ref.Split('#', 2)

    # If the reference source is specified, get the reference source and replace the input object
    # otherwise, use the input object as the reference source
    if (-not [string]::IsNullOrWhiteSpace($RefSource)) {
      if ([uri]::IsWellFormedUriString($RefSource, [System.UriKind]::Absolute)) {
        # If the reference source is an absolute URI, download the reference source and replace the input object
        $InputObject = Invoke-WebRequest -Uri $RefSource | ConvertFrom-Json -AsHashtable
      } elseif ($Path -and (Test-Path -Path (Join-Path $Path $RefSource))) {
        # If the reference source is a relative file path, read the reference source and replace the input object
        $InputObject = Get-Content -Path (Join-Path $Path $RefSource) -Raw | ConvertFrom-Json -AsHashtable
      } else {
        throw "The reference source `"${RefSource}`" is not a valid URI or a valid file path."
      }
    }

    # Get the target definition of the reference recursively
    $RefSegments = $RefPath -split '/'
    $Object = $InputObject
    foreach ($RefSegment in $RefSegments) {
      if (-not [string]::IsNullOrWhiteSpace($RefSegment)) {
        if ($Object.Contains($RefSegment)) {
          $Object = $Object[$RefSegment]
        } else {
          throw "The reference path `"${RefPath}`" is not valid."
        }
      }
    }

    return $Object
  }
}

function Expand-YamlSchema {
  <#
  .SYNOPSIS
    Replace the references in the given YAML schema with their target definitions
  .PARAMETER InputObject
    The YAML schema object
  .PARAMETER Clone
    Clone the objects inside the schema to a new object and output a new YAML schema object instead of in-place replacement
  .EXAMPLE
    Expand-YamlSchema -InputObject $Schema
  .EXAMPLE
    Expand-YamlSchema -InputObject $Schema -Clone
  #>
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The YAML schema object')]
    $InputObject,

    [Parameter(HelpMessage = 'Clone the objects inside the schema to a new object and output a new YAML schema object instead of in-place replacement')]
    [switch]$Clone,

    [Parameter(DontShow)]
    $RootObject = $InputObject
  )

  process {
    if ($Clone) {
      $OutputObject = [ordered]@{}
      # Check if an object contains a "$ref" key
      foreach ($Key in $InputObject.GetEnumerator()) {
        if ($InputObject.$Key -is [System.Collections.IDictionary]) {
          if ($InputObject.$Key.Contains('$ref')) {
            $OutputObject[$Key] = Get-YamlSchemaValue -InputObject $RootObject -Ref $InputObject.$Key.'$ref'
          } else {
            $OutputObject[$Key] = Expand-YamlSchema -InputObject $InputObject.$Key -RootObject $RootObject -Clone
          }
        } else {
          $OutputObject[$Key] = $InputObject.$Key
        }
      }

      return $OutputObject
    } else {
      # Check if an object contains a "$ref" key
      foreach ($Key in @($InputObject.Keys)) {
        if ($InputObject.$Key -is [System.Collections.IDictionary]) {
          if ($InputObject.$Key.Contains('$ref')) {
            $InputObject.$Key = Get-YamlSchemaValue -InputObject $RootObject -Ref $InputObject.$Key.'$ref'
          } else {
            Expand-YamlSchema -InputObject $InputObject.$Key -RootObject $RootObject
          }
        }
      }
    }
  }
}

function Test-YamlObject {
  <#
  .SYNOPSIS
    Validate a YAML object using the given schema
  .PARAMETER InputObject
    The YAML object to validate
  .PARAMETER Schema
    The YAML schema to use for validation
  .PARAMETER Recurse
    Recursively validate the nested objects and arrays
  .EXAMPLE
    Test-YamlObject -InputObject $Object -Schema $Schema
  .EXAMPLE
    Test-YamlObject -InputObject $Object -Schema $Schema -Recurse
  #>
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The YAML object to validate')]
    [AllowNull()]
    $InputObject,

    [Parameter(Mandatory, HelpMessage = 'The YAML schema to use for validation')]
    $Schema,

    [Parameter(HelpMessage = 'Recursively validate the nested objects and arrays')]
    [switch]$Recurse
  )

  process {
    if ($Schema.type -contains 'null' -and $null -eq $InputObject) {
      # If the schema allows null values and the input object is null, return $true
      return $true
    } elseif ($Schema.type -contains 'object') {
      if ($null -eq $InputObject) {
        # Check if the input object is null
        Write-Warning -Message 'The input object is not nullable'
        return $false
      } elseif ($InputObject -is [System.Collections.IDictionary]) {
        # Check if the input object contains all required properties
        if ($Schema.Contains('required')) {
          foreach ($RequiredProperty in $Schema.required) {
            if (-not $InputObject.Contains($RequiredProperty)) {
              Write-Warning -Message "The object does not contain the required property `"${RequiredProperty}`""
              return $false
            }
          }
        }
        # Check if the input object contains invalid properties
        if ($Recurse) {
          foreach ($Key in $Schema.properties.Keys) {
            if ($InputObject.Contains($Key) -and -not (Test-YamlObject -InputObject $InputObject[$Key] -Schema $Schema.properties.$Key -Recurse)) {
              Write-Warning -Message "The object contains an invalid value for the property `"${Key}`""
              return $false
            }
          }
        }
        # If all checks pass, return $true
        return $true
      } else {
        # If the input object is not of object type, return $false
        Write-Warning -Message 'The input object is not of object type'
        return $false
      }
    } elseif ($Schema.type -contains 'array') {
      if ($null -eq $InputObject) {
        # Check if the input object is null
        Write-Warning -Message 'The input object is not nullable'
        return $false
      } elseif ($InputObject -is [System.Collections.IEnumerable]) {
        # Check if the input object has the correct number of items
        if ($Schema.Contains('minItems') -and $InputObject.Count -lt $Schema.minItems) {
          Write-Warning -Message "The array has $($InputObject.Count) items, fewer than the minimum number of items $($Schema.minItems)"
          return $false
        }
        if ($Schema.Contains('maxItems') -and $InputObject.Count -gt $Schema.maxItems) {
          Write-Warning -Message "The array has $($InputObject.Count) items, more than the maximum number of items $($Schema.maxItems)"
          return $false
        }
        # Check if the input object contains invalid items
        if ($Recurse) {
          foreach ($Item in $InputObject) {
            if (-not (Test-YamlObject -InputObject $Item -Schema $Schema.items -Recurse)) {
              Write-Warning -Message 'The array contains an invalid item'
              return $false
            }
          }
        }
        # If all checks pass, return $true
        return $true
      } else {
        # If the input object is not of array type, return $false
        Write-Warning -Message 'The input object is not of array type'
        return $false
      }
    } elseif ($Schema.type -contains 'string') {
      if ($null -eq $InputObject) {
        # Check if the input object is null
        Write-Warning -Message 'The input object is not nullable'
        return $false
      } elseif ($InputObject -is [string]) {
        if ($Schema.Contains('enum') -and -not $Schema.enum.Contains($InputObject)) {
          # Check if the input object is not in the enum list
          Write-Warning -Message "The string `"${InputObject}`" is not in the enum list"
          return $false
        }
        if ($Schema.Contains('pattern') -and $InputObject -notmatch $Schema.pattern) {
          # Check if the input object does not match the pattern
          Write-Warning -Message "The string `"${InputObject}`" does not match the pattern"
          return $false
        }
        if ($Schema.Contains('minLength') -and $InputObject.Length -lt $Schema.minLength) {
          # Check if the input object is shorter than the minimum length
          Write-Warning -Message "The string `"${InputObject}`" has a length of $($InputObject.Length), shorter than the minimum length $($Schema.minLength)"
          return $false
        }
        if ($Schema.Contains('maxLength') -and $InputObject.Length -gt $Schema.maxLength) {
          # Check if the input object is longer than the maximum length
          Write-Warning -Message "The string has a length of $($InputObject.Length), longer than the maximum length $($Schema.maxLength)"
          return $false
        }
        # If all checks pass, return $true
        return $true
      } else {
        # If the input object is not of string type, return $false
        Write-Warning -Message 'The input object is not of string type'
        return $false
      }
    } elseif ($Schema.type -contains 'number' -or $Schema.type -contains 'integer') {
      if ($null -eq $InputObject) {
        # Check if the input object is null
        Write-Warning -Message 'The input object is not nullable'
        return $false
      } elseif ($InputObject -is [Int16] -or $InputObject -is [Int32] -or $InputObject -is [Int64] -or $InputObject -is [UInt16] -or $InputObject -is [UInt32] -or $InputObject -is [UInt64] -or $InputObject -is [Single] -or $InputObject -is [Double] -or $InputObject -is [Decimal]) {
        if ($Schema.type -contains 'integer' -and -not [int]::TryParse($InputObject, [ref]$null)) {
          # Check if the input object is not an integer
          Write-Warning -Message "The number `"${InputObject}`" is not an integer"
          return $false
        }
        if ($Schema.Contains('enum') -and -not $Schema.enum.Contains($InputObject)) {
          # Check if the input object is not in the enum list
          Write-Warning -Message "The number `"${InputObject}`" is not in the enum list"
          return $false
        }
        if ($Schema.Contains('minimum') -and $InputObject -lt $Schema.minimum) {
          # Check if the input object is smaller than the minimum value
          Write-Warning -Message "The number `"${InputObject}`" is smaller than the minimum value $($Schema.minimum)"
          return $false
        }
        if ($Schema.Contains('maximum') -and $InputObject -gt $Schema.maximum) {
          # Check if the input object is larger than the maximum value
          Write-Warning -Message "The number `"${InputObject}`" is larger than the maximum value $($Schema.maximum)"
          return $false
        }
        # If all checks pass, return $true
        return $true
      } else {
        # If the input object is not of number type, return $false
        Write-Warning -Message 'The input object is not of number type or integer type'
        return $false
      }
    } elseif ($Schema.type -contains 'boolean') {
      if ($null -eq $InputObject) {
        # Check if the input object is null
        Write-Warning -Message 'The input object is not nullable'
        return $false
      } elseif ($InputObject -is [bool]) {
        if ($Schema.Contains('enum') -and -not $Schema.enum.Contains($InputObject)) {
          # Check if the input object is not in the enum list
          Write-Warning -Message "The boolean `"${InputObject}`" is not in the enum list"
          return $false
        }
        # If all checks pass, return $true
        return $true
      } else {
        # If the input object is not of boolean type, return $false
        Write-Warning -Message 'The input object is not of boolean type'
        return $false
      }
    } else {
      # If the schema type is not supported, return $true
      throw "Unsupported schema type $($Schema.type)"
    }
  }
}

function ConvertTo-SortedYamlObject {
  <#
  .SYNOPSIS
    Sort the properties of a YAML object according to the schema
  .PARAMETER InputObject
    The YAML object to sort
  .PARAMETER Schema
    The YAML schema to use for sorting
  .PARAMETER Culture
    The locale format to use for sorting
  .EXAMPLE
    ConvertTo-SortedYamlObject -InputObject $Object -Schema $Schema
  .EXAMPLE
    ConvertTo-SortedYamlObject -InputObject $Object -Schema $Schema -Culture 'en-US'
  #>
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The YAML object to sort')]
    [AllowNull()]
    $InputObject,

    [Parameter(Mandatory, HelpMessage = 'The YAML schema to use for sorting')]
    $Schema,

    [Parameter(HelpMessage = 'The locale format to use for sorting')]
    [cultureinfo]$Culture = (Get-Culture)
  )

  process {
    if ($Schema.type -contains 'object') {
      if (-not (Test-YamlObject -InputObject $InputObject -Schema $Schema)) {
        throw 'The input object does not match the schema'
      }
      $OutputObject = [ordered]@{}
      foreach ($Key in $Schema.properties.Keys) {
        if ($InputObject.Contains($Key)) {
          $OutputObject.$Key = ConvertTo-SortedYamlObject -InputObject $InputObject.$Key -Schema $Schema.properties.$Key -Culture $Culture
        }
      }
      Write-Output -InputObject $OutputObject
    } elseif ($Schema.type -contains 'array') {
      if (-not (Test-YamlObject -InputObject $InputObject -Schema $Schema)) {
        throw 'The input object does not match the schema'
      }
      Write-Output -InputObject @($InputObject | ForEach-Object -Process { ConvertTo-SortedYamlObject -InputObject $_ -Schema $Schema.items -Culture $Culture } | Sort-Object -Stable -Culture $Culture) -NoEnumerate
    } else {
      return $InputObject
    }
  }
}
