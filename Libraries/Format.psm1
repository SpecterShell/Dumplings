<#
The codes were referenced from https://github.com/vinta/pangu.js under the MIT License

The MIT License (MIT)

Copyright (c) 2013 Vinta

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

# Apply default function parameters
if ($DumplingsDefaultParameterValues) { $PSDefaultParameterValues = $DumplingsDefaultParameterValues }

# Force stop on error
$ErrorActionPreference = 'Stop'

# Chinese, Japanese and Korean characters
$CJK = '\u2e80-\u2eff\u2f00-\u2fdf\u3040-\u309f\u30a0-\u30fa\u30fc-\u30ff\u3100-\u312f\u3200-\u32ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff'
# Alphabets
$A = 'A-Za-z\u0080-\u00ff\u0370-\u03ff'
# Numbers
$N = '0-9'
# All kinds of invisible characters except newline characters (CRLF and LF)
$INVISIBLE_EXCEPT_NEWLINE = '\f\t\v\u0085\p{Z}'

# Dot based ellipsis after CJK characters. They should be replace by character based ellipsis "……"
$HALFWIDTH_ELLIPSIS = "([${CJK}])(\.{3,})[${INVISIBLE_EXCEPT_NEWLINE}]*"
# Half width symbols after CJK characters. They should be replace by the full width ones
$HALFWIDTH_SYMBOLS = "(?m)(?<CJK>[${CJK}])(?<Symbols>[~!;:,?]+)[${INVISIBLE_EXCEPT_NEWLINE}]*"

# CJK characters before alphabets and numbers. A whitespace is needed between them
$CJK_AN = "([${CJK}])([${A}${N}])"
# CJK characters after alphabets and numbers. A whitespace is needed between them
$AN_CJK = "([${A}]|[${N}][+]?)([${CJK}])"

# The prefix of the ordered list
$ORDERED_LIST_PREFIX = "(?m)(?<=^[${N}]{1,2})([\.\u3001][${INVISIBLE_EXCEPT_NEWLINE}]*)([^\d])"
# The prefix of the unordered list
$UNORDERED_LIST_PREFIX = "(?m)(^[-·•][${INVISIBLE_EXCEPT_NEWLINE}]*)([^-])"
# Left bracket characters in full width, whose glyphs only take the right side
$FULLWIDTH_LEFT_BRACKET = @('【', '《', '（')

filter ConvertTo-FullWidth {
  <#
  .SYNOPSIS
    Convert half width symbols to full width symbols
  #>

  $_ `
    -creplace '~', '～' `
    -creplace '!', '！' `
    -creplace ';', '；' `
    -creplace ':', '：' `
    -creplace ',', '，' `
    -creplace '\.', '。' `
    -creplace '\?', '？'
}

function Format-Text {
  <#
  .SYNOPSIS
    Format the text through a set of regular expressions to make it neat and easy to read
  .DESCRIPTION
    This function applies a set of regular expressions to the text to make it neat and easy to read.

    Generally, it does the following:
    1. Replace line ending characters with LF
    2. Decode HTML escape characters
    3. Convert dot-based ellipsis after CJK characters to ellipsis symbol
    4. Convert half-width symbols after CJK characters to full-width symbols
    5. Insert a white space between CJK characters and alphabets + numbers and vice versa
    6. Remove invisible characters around the whole text and at the end of each line
       (Those at the beginning of each line are ignored to avoid losing the cascading style)
    7. Shrink 2+ continuous line endings into 2
    8. Format the prefix (ordered and unordered) of the list
    9. Replace ";" or "；" at the end of the whole text with "." or "。", respectively

    If multiple texts are piped to the function, they will be merged into one.
  .PARAMETER Text
    The text to be formatted
  .EXAMPLE
    "当你凝视着bug，bug也凝视着你" | Format-Text

    This will add a white space before the first "bug" and another one after the second "bug"
  .EXAMPLE
    $Text = @("CRLF`r`nis the default line ending on Windows", "LF`nis the default line ending on Linux") | Format-Text
    Write-Host @"
    Does the text contain CRLF? $($Text.Contains("`r"))
    What is the type of the object? An array or a string? $($Text.GetType())
    The content of the string:
    ${Text}
    "@

    This will combine multiple strings passed to the function into one while replacing the line endings with LF
  .EXAMPLE
    @'
    What's New:
    -Bug fixes and improvements;


    Recent Updates:
    1.Fixed PowerShell 7.4 compatibility issues;
    2.Minor bug fixes;
    '@ | Format-Text

    This will add a white space after each prefix ("-", "1." and "2."), shrink three line endings into two, and replace the ";" at the end of the whole text with "."
  #>
  [OutputType([string])]
  param (
    [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The text to be formatted')]
    [AllowEmptyString()]
    [string]$Text
  )

  begin {
    $Result = [System.Collections.Generic.List[string]]::new()
  }

  process {
    # Replace line ending characters with LF
    $Result.Add($Text.ReplaceLineEndings("`n"))
  }

  end {
    $Result = $Result -join "`n"

    # Decode HTML escape characters
    $Result = [System.Web.HttpUtility]::HtmlDecode($Result)

    # Convert dot-based ellipsis after CJK characters to ellipsis symbol
    $Result = $Result -creplace $HALFWIDTH_ELLIPSIS, '$1……'
    # Convert half-width symbols after CJK characters to full-width symbols
    $Result = $Result -creplace $HALFWIDTH_SYMBOLS, { $_.Groups['CJK'].Value + ($_.Groups['Symbols'].Value | ConvertTo-FullWidth) }

    # Insert a white space between CJK character and AN
    $Result = $Result -creplace $CJK_AN, '$1 $2'
    # Insert a white space between AN(S) and CJK character
    $Result = $Result -creplace $AN_CJK, '$1 $2'

    # Remove invisible characters around the whole text
    $Result = $Result.Trim()
    # Remove invisible characters at the end of each line
    $Result = $Result -creplace "(?m)[${INVISIBLE_EXCEPT_NEWLINE}]+$", ''

    # Shrink 2+ continuous line endings into 2
    $Result = $Result -creplace '(\r\n|\n){3,}', "`n`n"

    # Format the prefix of the ordered list
    $Result = $Result -creplace $ORDERED_LIST_PREFIX, { ($_.Groups[2].Value -in $FULLWIDTH_LEFT_BRACKET ? '.' : '. ') + $_.Groups[2].Value }
    # Format the prefix of the unordered list
    $Result = $Result -creplace $UNORDERED_LIST_PREFIX, { ($_.Groups[2].Value -in $FULLWIDTH_LEFT_BRACKET ? '-' : '- ') + $_.Groups[2].Value }

    # Replace ";" or "；" at the end of the whole text with "." or "。", respectively
    $Result = $Result -creplace '(?s);$', '.' -creplace '(?s)；$', '。'

    return $Result
  }
}

Export-ModuleMember -Function Format-Text
