<#
.SYNOPSIS
  Get text content from HTML Agility Pack node(s)
#>

# Node types that will not be added to the final list
$IgnoredNodes = @('img', 'script', 'style', 'video')
# Node types that always start at new line
# https://developer.mozilla.org/docs/Web/HTML/Block-level_elements
$BlockNodes = @(
  'address', 'article', 'aside', 'blockquote', 'dd', 'div', 'dl',
  'fieldset', 'figcaption', 'figure', 'footer', 'form',
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'hgroup', 'hr',
  'li', # Treat <li> as block node
  'ol', 'p', 'pre', 'section', 'table', 'ul'
)

function Expand-Node {
  <#
  .SYNOPSIS
    Extract the child nodes from the inline nodes
  .PARAMETER Node
    The HTML Agility Pack nodes that will be expanded
  #>
  param (
    [Parameter(
      ValueFromPipeline,
      HelpMessage = 'The nodes list that will be expanded'
    )]
    $Node
  )

  begin {
    $Nodes = @()
  }

  process {
    $Nodes += $Node
  }

  end {
    $ChildNodes = @()

    switch ($Nodes) {
      # Do not add unnecessary nodes to the list
      ({ $_.Name -in $IgnoredNodes }) { continue }
      # Keep and add block nodes to the list
      ({ $_.Name -in $BlockNodes }) { $ChildNodes += $_; continue }
      # Extract the child nodes of the inline nodes and add them to the list
      ({ $_.ChildNodes }) { $ChildNodes += Expand-Node -Node $_.ChildNodes; continue }
      # In case something went wrong
      Default { $ChildNodes += $_; continue }
    }

    return $ChildNodes
  }
}

function Get-TextContent {
  <#
  .SYNOPSIS
    Get text content from HTML Agility Pack node(s)
  .PARAMETER Node
    The HTML Agility Pack nodes containing the text
  .PARAMETER ListInfo
    The hashtable containing the list type and the list number, designed for internal use
  .EXAMPLE
    Invoke-WebRequest -Uri 'https://example.com/' | ConvertFrom-Html | Get-TextContent | Format-Text
    ConvertFrom-HTML is a function from the PowerShell module PowerHTML
  .EXAMPLE
    (Invoke-WebRequest -Uri 'https://example.com/' | ConvertFrom-Html).SelectSingleNode('/html/body/div/p[1]') | Get-TextContent | Format-Text
  #>
  param (
    [Parameter(
      ValueFromPipeline,
      HelpMessage = 'The nodes that containing the text'
    )]
    $Node,

    [Parameter(
      DontShow,
      HelpMessage = 'The list info hashtable for internal use'
    )]
    $ListInfo
  )

  begin {
    $Nodes = @()
  }

  process {
    $Nodes += $Node
  }

  end {
    $Content = ''
    $Nodes = Expand-Node -Node $Nodes
    # If the previous node is a block element, add a newline before the next node
    $NextNewLine = $false

    foreach ($Node in $Nodes) {
      switch ($Node.Name) {
        '#text' {
          $Text = [System.Web.HttpUtility]::HtmlDecode($Node.InnerText.Trim())
          # In case the text node is a fake node that works as a placeholder between the nodes
          if (-not [string]::IsNullOrEmpty($Text)) {
            if ($NextNewLine) {
              $Content += "`n"
              $NextNewLine = $false
            }
            $Content += $Text
          }
        }
        'br' {
          if ($NextNewLine) {
            $Content += "`n"
            $NextNewLine = $false
          }
          $Content += "`n"
        }
        Default {
          if (-not [string]::IsNullOrEmpty($Content)) {
            $Content += "`n"
          }
          switch ($Node.Name) {
            # Unordered list
            'ul' { $Content += Get-TextContent $Node.ChildNodes @{ Type = 'Unordered'; Number = 1 } }
            # Ordered list
            'ol' { $Content += Get-TextContent $Node.ChildNodes @{ Type = 'Ordered'; Number = 1 } }
            # List entry
            'li' {
              if ($ListInfo -and $ListInfo.Type -eq 'Ordered') {
                $Content += "$(($ListInfo.Number++)). "
              } else {
                $Content += '- '
              }
              $Content += (Get-TextContent $Node.ChildNodes $ListInfo).TrimStart()
            }
            Default { $Content += Get-TextContent $Node.ChildNodes $ListInfo }
          }
          $NextNewLine = $true
        }
      }
    }
    return $Content
  }
}

Export-ModuleMember -Function Get-TextContent
