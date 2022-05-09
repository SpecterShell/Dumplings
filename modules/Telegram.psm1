# Telegram Bot token
$TGBotToken = $env:TG_BOT_TOKEN
# Telegram Chat ID
$TGChatID = $env:TG_CHAT_ID

filter Send-TelegramMessage {
    <#
    .SYNOPSIS
        Function to send message using Telegram Bot API
    .OUTPUTS
        pscustomobject
    #>

    # Avoid conflicts
    $Session = $_

    if (-not ($TGBotToken -and $TGChatID)) {
        Write-Error -Message 'Either Telegram Bot token or Telegram Chat ID is not given, skip sending' -CategoryActivity 'Panda'
        return $Session
    }

    $Message = "$($Session.Config.Identifier)`n"
    if ($Session.CurrentState.Version) {
        $Message += "版本：$($Session.LastState.Version) -> $($Session.CurrentState.Version)`n"
    }
    if ($Session.CurrentState.InstallerUrls) {
        $Message += "地址：`n$($Session.CurrentState.InstallerUrls -join "`n")`n"
    }
    if ($Session.CurrentState.ReleaseTime) {
        $Message += $Session.CurrentState.ReleaseTime -is [datetime]? `
            "日期：$($Session.CurrentState.ReleaseTime.ToString('yyyy-MM-dd'))`n": `
            "日期：$($Session.CurrentState.ReleaseTime)`n"
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
    $Payload = @{
        chat_id = $TGChatID
        text    = $Message
    }
    $Request = @{
        Uri         = "https://api.telegram.org/bot$($TGBotToken)/sendMessage"
        Method      = 'Post'
        Body        = ([System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $payload -Compress)))
        ContentType = 'application/json'
    }
    try {
        Invoke-RestMethod @Request | Out-Null
    }
    catch {
        Write-Error -Message "Failed to push to Telegram: $($_.Exception.Message)" -CategoryActivity $Session.Config.Identifier
    }
    return $Session
}

Export-ModuleMember -Function Send-TelegramMessage
