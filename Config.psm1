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
        if ($Session.CurrentState.ReleaseTime -is [datetime]) {
            $Message += "日期：$($Session.CurrentState.ReleaseTime.ToString('yyyy-MM-dd'))`n"
        }
        else {
            $Message += "日期：$($Session.CurrentState.ReleaseTime)`n"
        }
    }
    if ($Session.CurrentState.ReleaseNotes) {
        $Message += "内容：`n$($Session.CurrentState.ReleaseNotes)`n"
    }
    if ($Session.CurrentState.ReleaseNotesUrl) {
        $Message += "链接：$($Session.CurrentState.ReleaseNotesUrl)`n"
    }
    if ($Session.Config.Note) {
        $Message += "注释：`n$($Session.Config.Note)"
    }

    return $Message
}

Export-ModuleMember -Variable DefaultTemplate
