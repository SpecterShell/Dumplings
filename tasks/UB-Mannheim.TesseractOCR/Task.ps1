$Config = @{
    Identifier = 'UB-Mannheim.TesseractOCR'
    Skip       = $false
}

$Ping = {
    $Uri = 'https://digi.bib.uni-mannheim.de/tesseract/?C=M;O=D;F=0;P=*.exe'
    $Prefix = 'https://digi.bib.uni-mannheim.de/tesseract/'
    $Content = (Invoke-WebRequest -Uri $Uri).Content

    $Result = [ordered]@{}

    # Version
    $Result.Version = [regex]::Match($Content, 'tesseract-ocr-w64-setup-(v[\d\.]+)\.exe').Groups[1].Value

    # InstallerUrl
    $Result.InstallerUrl = @(
        "${Prefix}tesseract-ocr-w32-setup-$($Result.Version).exe",
        "${Prefix}tesseract-ocr-w64-setup-$($Result.Version).exe"
    )

    # ReleaseTime
    $Result.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($Result.Version, '(\d{8})').Groups[1].Value,
        'yyyyMMdd',
        $null
    ).ToString('yyyy-MM-dd')

    # ReleaseNotesUrl
    $Result.ReleaseNotesUrl = 'https://github.com/UB-Mannheim/tesseract/wiki'

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
