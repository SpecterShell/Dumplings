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
        $Message += "`n版本：" + $Session.LastState.Version + ' -> ' + $Session.CurrentState.Version
    }
    if ($Session.CurrentState.InstallerUrl) {
        $Message += "`n地址：`n" + ($Session.CurrentState.InstallerUrl -join "`n")
    }
    if ($Session.CurrentState.ReleaseTime) {
        $Message += $Session.CurrentState.ReleaseTime -is [datetime]? `
            "`n日期：" + $Session.CurrentState.ReleaseTime.ToString('yyyy-MM-dd'): `
            "`n日期：" + $Session.CurrentState.ReleaseTime
    }
    if ($Session.CurrentState.ReleaseNotes) {
        $Message += "`n内容：`n" + $Session.CurrentState.ReleaseNotes
    }
    if ($Session.CurrentState.ReleaseNotesUrl) {
        $Message += "`n链接：" + $Session.CurrentState.ReleaseNotesUrl
    }
    if ($Session.Config.Note) {
        $Message += "`n注释：`n" + $Session.Config.Note
    }

    return $Message
}

$DefaultWebRequestParameters = @{
    TimeoutSec        = 500
    MaximumRetryCount = 5
    RetryIntervalSec  = 5
}

Export-ModuleMember -Variable DefaultTemplate, DefaultWebRequestParameters
