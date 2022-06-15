function ConvertFrom-Ini {
    <#
    .SYNOPSIS
        Convert INI string into ordered hashtable
    .PARAMETER InputObject
        The INI string
    .PARAMETER CommentChars
        The characters that describe a comment
        Lines starting with the characters provided will be rendered as comments
        Default: ";"
    .PARAMETER IgnoreComments
        Remove lines determined to be comments from the resulting dictionary
    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary
    .LINK
        https://github.com/lipkau/PsIni
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $InputObject,

        [char[]]
        $CommentChars = @(';'),

        [switch]
        $IgnoreComments
    )

    begin {
        $SectionRegex = '^\s*\[(.+)\]\s*$'
        $KeyRegex = "^\s*(.+?)\s*=\s*(['`"]?)(.*)\2\s*$"
        $CommentRegex = "^\s*[$($CommentChars -join '')](.*)$"

        # Name of the section, in case the INI string had none
        $NoSection = '_'
    }

    process {
        $Object = [ordered]@{}
        $CommentCount = 0
        switch -Regex ($InputObject -csplit '\r\n|\n') {
            $SectionRegex {
                $Section = $Matches[1]
                $Object[$Section] = [ordered]@{}
                $CommentCount = 0
                continue
            }
            $CommentRegex {
                if (-not $IgnoreComments) {
                    if (-not $Section) {
                        $Section = $NoSection
                        $Object[$Section] = [ordered]@{}
                    }
                    $Name = '#Comment' + $CommentCount
                    $Value = $Matches[1]
                    $Object[$Section][$Name] = $Value
                    ++$CommentCount
                }
                continue
            }
            $KeyRegex {
                if (-not $Section) {
                    $Section = $NoSection
                    $Object[$Section] = [ordered]@{}
                }
                $Name, $Value = $Matches[1, 3]
                if ($Object[$Section][$Name]) {
                    if ($Object[$Section][$Name] -is [array]) {
                        $Object[$Section][$Name] += $Value
                    }
                    else {
                        $Object[$Section][$Name] = @($Object[$Section][$Name], $Value)
                    }
                }
                else {
                    $Object[$Section][$Name] = $Value
                }
                continue
            }
        }
        return $Object
    }
}

Export-ModuleMember -Function ConvertFrom-Ini
