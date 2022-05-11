filter ConvertFrom-ElectronUpdater {
    <#
    .SYNOPSIS
        Convert a electron-updater YAML update source into to a PSCustomObject object
    .PARAMETER Prefix
        The prefix of the InstallerUrls
    .OUTPUTS
        pscustomobject
    #>
    param (
        [string]
        $Prefix
    )

    $Result = [PSCustomObject]@{}
    $Object = $_ | ConvertFrom-Yaml

    # Version
    if ($Object.version) {
        Add-Member -MemberType NoteProperty -Name 'Version' -Value $Object.version -InputObject $Result
    }

    # InstallerUrls
    if ($Object.files) {
        $InstallerUrls = "$($Prefix)$([System.Uri]::EscapeDataString($Object.files[0].url))"
        Add-Member -MemberType NoteProperty -Name 'InstallerUrls' -Value $InstallerUrls -InputObject $Result
    }

    # ReleaseTime
    if ($Object.releaseDate) {
        Add-Member -MemberType NoteProperty -Name 'ReleaseTime' -Value $Object.releaseDate.ToUniversalTime() -InputObject $Result
    }

    # ReleaseNotes
    if ($Object.releaseNotes) {
        Add-Member -MemberType NoteProperty -Name 'ReleaseNotes' -Value ($Object.releaseNotes | Format-Text) -InputObject $Result
    }

    return $Result
}

Export-ModuleMember -Function ConvertFrom-ElectronUpdater
