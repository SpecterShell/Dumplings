filter ConvertFrom-ElectronUpdater {
    <#
    .SYNOPSIS
        Convert a electron-updater YAML update source into to a PSCustomObject object
    .PARAMETER Prefix
        The prefix of the InstallerUrl
    #>
    param (
        [string]
        $Prefix
    )

    $Result = [ordered]@{}

    # Version
    if ($_.version) {
        $Result.Version = $_.version
    }

    # InstallerUrl
    if ($_.files) {
        $InstallerUrl = $Prefix + $_.files[0].url
        $Result.InstallerUrl = $InstallerUrl
    }

    # ReleaseTime
    if ($_.releaseDate) {
        $Result.ReleaseTime = $_.releaseDate.ToUniversalTime()
    }

    # ReleaseNotes
    if ($_.releaseNotes) {
        $Result.ReleaseNotes = $_.releaseNotes | Format-Text
    }

    return $Result
}

Export-ModuleMember -Function ConvertFrom-ElectronUpdater
