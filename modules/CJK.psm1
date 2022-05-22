$CJK = '\u2e80-\u2eff\u2f00-\u2fdf\u3040-\u309f\u30a0-\u30fa\u30fc-\u30ff\u3100-\u312f\u3200-\u32ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff'
$A = 'A-Za-z\u0080-\u00ff\u0370-\u03ff'
$N = '0-9'
$CONVERT_TO_FULLWIDTH_CJK_SYMBOLS_CJK = "(?m)(?<LeftCJK>[${CJK}])[ ]*(?<Symbols>[\:]+|\.)[ ]*(?<RightCJK>[${CJK}])"
$CONVERT_TO_FULLWIDTH_CJK_SYMBOLS = "(?m)(?<CJK>[${CJK}])[ ]*(?<Symbols>[~\!;,\?]+)[ ]*"
$CJK_AN = "([${CJK}])([${A}${N}])"
$AN_CJK = "([${A}${N}])([${CJK}])"
$ORDERED_LIST_NUMBER = "(?m)(?<=^[${N}]+)([\.\u3001-] *)"
$UNORDERED_LIST_NUMBER = '(?m)(^[-·] *)'

filter ConvertTo-FullWidth {
    <#
    .SYNOPSIS
        Convert half width symbols between or after CJK characters to full width symbols
    .OUTPUTS
        string
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
        Perform a set of formatting rules on the text
    .OUTPUTS
        string
    .NOTES
        CJK = Chinese, Japanese and Korean
        ANS = Alphabets, Numbers and Symbols
    .LINK
        https://github.com/vinta/pangu.js
    #>
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]
        $Text
    )

    begin {
        $Result = @()
    }

    process {
        $Result += $Text
    }

    end {
        $Result = $Result -join "`n"

        # Remove empty characters at the beginning and the end of each line
        $Result = $Result -creplace '(?m)^\s+', '' -creplace '(?m)\s+$', ''
        # Remove empty characters at the beginning and the end of the text
        $Result = $Result -creplace '^\s+', '' -creplace '\s+$', ''
        # Format the prefix of the ordered list
        $Result = $Result -creplace $ORDERED_LIST_NUMBER, "`. "
        # Format the prefix of the unordered list
        $Result = $Result -creplace $UNORDERED_LIST_NUMBER, '- '
        # Convert half width symbols between CJK characters to full width symbols
        $Result = $Result -creplace $CONVERT_TO_FULLWIDTH_CJK_SYMBOLS_CJK, { "$($_.Groups['LeftCJK'].Value)$($_.Groups['Symbols'].Value | ConvertTo-FullWidth)$($_.Groups['RightCJK'].Value)" }
        # Convert half width symbols after CJK characters to full width symbols
        $Result = $Result -creplace $CONVERT_TO_FULLWIDTH_CJK_SYMBOLS, { "$($_.Groups['CJK'].Value)$($_.Groups['Symbols'].Value | ConvertTo-FullWidth)" }
        # Add space between CJK characters and ANS
        $Result = $Result -creplace $CJK_AN, '$1 $2'
        # Add space between ANS and CJK characters
        $Result = $Result -creplace $AN_CJK, '$1 $2'
        return $Result
    }
}

Export-ModuleMember -Function Format-Text
