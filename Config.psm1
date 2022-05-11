$DefaultTemplate = {
    param (
        [parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true
        )]
        $Session
    )

    $Message = "$($Session.Config.Identifier)"
    if ($Session.CurrentState.Version) {
        $Message += "`n版本：$($Session.LastState.Version) -> $($Session.CurrentState.Version)"
    }
    if ($Session.CurrentState.InstallerUrls) {
        $Message += "`n地址：`n$($Session.CurrentState.InstallerUrls -join "`n")"
    }
    if ($Session.CurrentState.ReleaseTime) {
        if ($Session.CurrentState.ReleaseTime -is [datetime]) {
            $Message += "`n日期：$($Session.CurrentState.ReleaseTime.ToString('yyyy-MM-dd'))"
        }
        else {
            $Message += "`n日期：$($Session.CurrentState.ReleaseTime)"
        }
    }
    if ($Session.CurrentState.ReleaseNotes) {
        $Message += "`n内容：`n$($Session.CurrentState.ReleaseNotes)"
    }
    if ($Session.CurrentState.ReleaseNotesUrl) {
        $Message += "`n链接：$($Session.CurrentState.ReleaseNotesUrl)"
    }
    if ($Session.Config.Note) {
        $Message += "`n注释：`n$($Session.Config.Note)"
    }

    return $Message
}

$WebRequestParameters = @{
    TimeoutSec        = 500
    MaximumRetryCount = 5
    RetryIntervalSec  = 5
}

Export-ModuleMember -Variable DefaultTemplate, WebRequestParameters
