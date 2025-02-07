#Requires -Module PowerHTML

# Apply default function parameters
if ($DumplingsDefaultParameterValues) { $PSDefaultParameterValues = $DumplingsDefaultParameterValues }

# Force stop on error
$ErrorActionPreference = 'Stop'

# Node types that will be ignored during traversing
$IgnoredNodes = @('img', 'script', 'style', 'video', '#comment')
# Node types that always start at new line, as well as <li>
# https://developer.mozilla.org/docs/Web/HTML/Block-level_elements
$BlockNodes = @(
  'address', 'article', 'aside', 'blockquote', 'dd', 'div', 'dl',
  'fieldset', 'figcaption', 'figure', 'footer', 'form',
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'hgroup', 'hr',
  'li', 'ol', 'p', 'pre', 'section', 'table', 'ul',
  'tr'
)

function Expand-Node {
  <#
  .SYNOPSIS
    Extract the child nodes from the inline nodes
  .PARAMETER Node
    The HTML Agility Pack nodes that will be expanded
  #>
  param (
    [Parameter(ValueFromPipeline, HelpMessage = 'The nodes list that will be expanded')]
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
      ({ $_.HasChildNodes }) { $ChildNodes += Expand-Node -Node $_.ChildNodes; continue }
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
  .EXAMPLE
    Invoke-WebRequest -Uri 'https://example.com/' | ConvertFrom-Html | Get-TextContent | Format-Text
    ConvertFrom-HTML is a function from the PowerShell module PowerHTML
  .EXAMPLE
    (Invoke-WebRequest -Uri 'https://example.com/' | ConvertFrom-Html).SelectSingleNode('/html/body/div/p[1]') | Get-TextContent | Format-Text
  #>
  param (
    [Parameter(ValueFromPipeline, HelpMessage = 'The nodes that containing the text')]
    $Node,

    [Parameter(DontShow, HelpMessage = 'Disable merging continuous invisible characters')]
    [bool]
    $Raw = $false,

    [Parameter(DontShow, HelpMessage = 'The list info hashtable for internal use')]
    $ListInfo
  )

  begin {
    $Nodes = @()
  }

  process {
    $Nodes += $Node
  }

  end {
    $Content = [System.Text.StringBuilder]::new(2048)
    $Nodes = Expand-Node -Node $Nodes
    # The name of the last node. Leave blank to indicate it is at the beginning of the document/child node
    $LastNodeName = ''
    # Append single whitespace if there are whitespace(s) between visble texts from two text nodes
    $NextWhiteSpace = $false

    switch ($Nodes) {
      ({ $_.Name -eq '#text' }) {
        if ($Raw) {
          # In some elements such as <pre> invisible character is rendered as is
          $NewContent = $_.InnerText
        } else {
          # The browsers merge continuous invisible characters into one whitespace while HtmlAgilityPack doesn't. Do this manually
          $NewContent = $_.InnerText -creplace '\s+', ' '
        }
        if ($LastNodeName -eq '#text') {
          if ([string]::IsNullOrWhiteSpace($NewContent)) {
            $NextWhiteSpace = $true
          } else {
            if ($NewContent -cmatch '^\s+') {
              $NextWhiteSpace = $true
            }
            if ($NextWhiteSpace -eq $true) {
              $Content = $Content.Append(' ')
              $NextWhiteSpace = $false
            }
            $Content = $Content.Append([System.Web.HttpUtility]::HtmlDecode($NewContent.Trim()))
            if ($NewContent -cmatch '\s+$') {
              $NextWhiteSpace = $true
            }
          }
          $LastNodeName = $_.Name
        } else {
          if (-not [string]::IsNullOrWhiteSpace($NewContent)) {
            # Append newline if the last node is a block node
            if ($LastNodeName) {
              $Content = $Content.Append("`n")
            }
            $Content = $Content.Append([System.Web.HttpUtility]::HtmlDecode($NewContent.Trim()))
            if ($NewContent -cmatch '\s+$') {
              $NextWhiteSpace = $true
            }
            $LastNodeName = $_.Name
          }
        }
        continue
      }
      ({ $_.Name -eq 'br' }) {
        # Append additional newline only if the last node is a block element
        if ($LastNodeName -and $LastNodeName -ne '#text') {
          $Content = $Content.Append("`n")
        }
        $NextWhiteSpace = $false
        $LastNodeName = $_.Name
        continue
      }
      ({ $_ -is [HtmlAgilityPack.HtmlNode] }) {
        # Append newline only if there are preceding nodes
        if ($LastNodeName) {
          $Content = $Content.Append("`n")
        }
        if ($_.Name -eq 'ul') {
          $Content = $Content.Append((Get-TextContent -Node $_.ChildNodes -Raw $Raw -ListInfo @{ Type = 'Unordered'; Number = 1 }))
        } elseif ($_.Name -eq 'ol') {
          if ($_.Attributes.Contains('Start') -and [int]::TryParse($_.Attributes['Start'].Value, [ref]$null)) {
            $Content = $Content.Append((Get-TextContent -Node $_.ChildNodes -Raw $Raw -ListInfo @{ Type = 'Ordered'; Number = [int]$_.Attributes['Start'].Value }))
          } else {
            $Content = $Content.Append((Get-TextContent -Node $_.ChildNodes -Raw $Raw -ListInfo @{ Type = 'Ordered'; Number = 1 }))
          }
        } elseif ($_.Name -eq 'li') {
          $Prefix = '- '
          if ($ListInfo -and $ListInfo.Type -eq 'Ordered') {
            $Prefix = "$(($ListInfo.Number++)). "
          }
          # Prepend whitespaces to every line, and replace whitespaces in the first line with prefix
          $Content = $Content.Append(((Get-TextContent -Node $_.ChildNodes -Raw $Raw -ListInfo $ListInfo) -creplace '(?m)^', (' ' * $Prefix.Length)).Remove(0, $Prefix.Length).Insert(0, $Prefix))
        } elseif ($_.Name -eq 'pre') {
          $Content = $Content.Append((Get-TextContent -Node $_.ChildNodes -Raw $true -ListInfo $ListInfo))
        } else {
          $Content = $Content.Append((Get-TextContent -Node $_.ChildNodes -Raw $Raw -ListInfo $ListInfo))
        }
        $NextWhiteSpace = $false
        $LastNodeName = $_.Name
        continue
      }
    }
    return $Content.ToString()
  }
}

function Convert-MarkdownToHtml {
  <#
  .SYNOPSIS
    Convert Markdown content to HTML object
  .PARAMETER Content
    The Markdown content
  .PARAMETER Extensions
    The Markdig Markdown extensions to be added to the pipeline
  #>
  [OutputType([HtmlAgilityPack.HtmlNode])]
  [OutputType([HtmlAgilityPack.HtmlDocument])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory, HelpMessage = 'The Markdown content')]
    [AllowEmptyString()]
    [string]$Content,

    [Parameter(Position = 1, HelpMessage = 'The Markdig Markdown extensions to be added to the pipeline')]
    [ValidateSet('common', 'advanced', 'pipetables', 'gfm-pipetables', 'emphasisextras', 'listextras', 'hardlinebreak', 'footnotes', 'footers', 'citations', 'attributes', 'gridtables', 'abbreviations', 'emojis', 'definitionlists', 'customcontainers', 'figures', 'mathematics', 'bootstrap', 'medialinks', 'smartypants', 'autoidentifiers', 'tasklists', 'diagrams', 'nofollowlinks', 'noopenerlinks', 'noreferrerlinks', 'nohtml', 'yaml', 'nonascii-noescape', 'autolinks', 'globalization')]
    [string[]]$Extensions = @('advanced')
  )

  begin {
    $Pipeline = [Markdig.MarkdownExtensions]::Configure([Markdig.MarkdownPipelineBuilder]::new(), ($Extensions -join '+')).Build()
  }

  process {
    [Markdig.Markdown]::ToHtml($Content, $Pipeline) | ConvertFrom-Html
  }
}

Export-ModuleMember -Function Get-TextContent, Convert-MarkdownToHtml
