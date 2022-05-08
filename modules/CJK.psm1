$CJK = '\u2e80-\u2eff\u2f00-\u2fdf\u3040-\u309f\u30a0-\u30fa\u30fc-\u30ff\u3100-\u312f\u3200-\u32ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff'
$A = 'A-Za-z\u0080-\u00ff\u0370-\u03ff'
$N = '0-9'
$CONVERT_TO_FULLWIDTH_CJK_SYMBOLS_CJK = "(?m)(?<LeftCJK>[${CJK}])[ ]*(?<Symbols>[\:]+|\.)[ ]*(?<RightCJK>[${CJK}])"
$CONVERT_TO_FULLWIDTH_CJK_SYMBOLS = "(?m)(?<CJK>[${CJK}])[ ]*(?<Symbols>[~\!;,\?]+)[ ]*"
$CJK_AN = "([${CJK}])([${A}${N}])"
$AN_CJK = "([${A}${N}])([${CJK}])"
$NUMBER_SYMBOLS_TEXT = "(?m)(?<=^[${N}])([\.\u3001-] *)"
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

filter Format-Text {
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

    if ($_ -is [string]) {
        if ($_.Length -le 1 -or $_ -cnotmatch "[${CJK}]") {
            return $_
        }
        else {
            $Text = $_
            # Convert half width symbols between CJK characters to full width symbols
            $Text = $Text -creplace $CONVERT_TO_FULLWIDTH_CJK_SYMBOLS_CJK, { "$($_.Groups['LeftCJK'].Value)$($_.Groups['Symbols'].Value | ConvertTo-FullWidth)$($_.Groups['RightCJK'].Value)" }
            # Convert half width symbols after CJK characters to full width symbols
            $Text = $Text -creplace $CONVERT_TO_FULLWIDTH_CJK_SYMBOLS, { "$($_.Groups['CJK'].Value)$($_.Groups['Symbols'].Value | ConvertTo-FullWidth)" }
            # Format the prefix of the ordered list
            $Text = $Text -creplace $NUMBER_SYMBOLS_TEXT, "`. "
            # Add space between CJK characters and ANS
            $Text = $Text -creplace $CJK_AN, '$1 $2'
            # Add space between ANS and CJK characters
            $Text = $Text -creplace $AN_CJK, '$1 $2'
            # Remove empty characters at the beginning and the end of each line
            $Text = $Text -creplace '(?m)^\s*', '' -creplace '(?m)\s*$', ''
            return $Text
        }
    }
}

Export-ModuleMember -Function Format-Text
