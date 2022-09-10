$DefaultTemplate = {
    param (
        [parameter(Mandatory)]
        $Session
    )

    $Message = "$($Session.Config.Identifier)"
    if ($Session.Config.Notes) {
        $Message += "`n" + $Session.Config.Notes
    }
    if ($Session.CurrentState.Version) {
        if ($Session.CurrentState.RealVersion) {
            $Message += "`n`n版本：`n$($Session.LastState.RealVersion) ($($Session.LastState.Version)) → $($Session.CurrentState.RealVersion) ($($Session.CurrentState.Version))"
        }
        else {
            $Message += "`n`n版本：`n" + $Session.LastState.Version + ' → ' + $Session.CurrentState.Version
        }
    }
    if ($Session.CurrentState.InstallerUrl) {
        $Message += "`n`n地址：`n" + (($Session.CurrentState.InstallerUrl | ForEach-Object -Process { [uri]::EscapeUriString($_) }) -join "`n")
    }
    if ($Session.CurrentState.ReleaseTime) {
        $Message += "`n`n日期：`n"
        if ($Session.CurrentState.ReleaseTime -is [datetime]) {
            $Message += $Session.CurrentState.ReleaseTime.ToString('yyyy-MM-dd')
        }
        else {
            $Message += $Session.CurrentState.ReleaseTime
        }
    }
    if ($Session.CurrentState.ReleaseNotes) {
        $Message += "`n`n内容：`n" + $Session.CurrentState.ReleaseNotes
    }
    if ($Session.CurrentState.ReleaseNotesCN) {
        $Message += "`n`n内容（中文）：`n" + $Session.CurrentState.ReleaseNotesCN
    }
    if ($Session.CurrentState.ReleaseNotesUrl) {
        $Message += "`n`n链接：`n" + $Session.CurrentState.ReleaseNotesUrl
    }
    if ($Session.CurrentState.ReleaseNotesUrlCN) {
        $Message += "`n`n链接（中文）：`n" + $Session.CurrentState.ReleaseNotesUrlCN
    }

    return $Message
}

$DefaultComparedProperties = @('Version', 'InstallerUrl')

$DefaultWebRequestParameters = @{
    'Invoke-WebRequest:TimeoutSec'        = 512
    'Invoke-WebRequest:MaximumRetryCount' = 4
    'Invoke-WebRequest:RetryIntervalSec'  = 16
    'Invoke-RestMethod:TimeoutSec'        = 512
    'Invoke-RestMethod:MaximumRetryCount' = 4
    'Invoke-RestMethod:RetryIntervalSec'  = 16
}

Export-ModuleMember -Variable *
