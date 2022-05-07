$DefaultTemplate = {
    param (
        [parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true
        )]
        $Session
    )

    $Message = "$($Session.Config.Identifier)`n"
    if ($Session.CurrentState.Version) {
        $Message += "版本：$($Session.LastState.Version) -> $($Session.CurrentState.Version)`n"
    }
    if ($Session.CurrentState.InstallerUrls) {
        $Message += "地址：`n$($Session.CurrentState.InstallerUrls -join "`n")`n"
    }
    if ($Session.CurrentState.ReleaseTime) {
        $Message += "日期：$($Session.CurrentState.ReleaseTime.ToString('yyyy-MM-dd'))`n"
    }
    if ($Session.CurrentState.ReleaseNotes) {
        $Message += "内容：`n$($Session.CurrentState.ReleaseNotes)`n"
    }
    if ($Session.CurrentState.ReleaseNotesUrl) {
        $Message += "链接：$($Session.CurrentState.ReleaseNotesUrl)"
    }
    if ($Session.Config.Notes) {
        $Message += "注释：$($Session.Config.Notes)"
    }

    return $Message
}

Export-ModuleMember -Variable DefaultTemplate
