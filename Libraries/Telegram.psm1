param (
  [Parameter(
    Mandatory,
    HelpMessage = 'Telegram Bot token'
  )]
  [string]
  $BotToken = $Env:TG_BOT_TOKEN,

  [Parameter(
    Mandatory,
    HelpMessage = 'Telegram Chat ID'
  )]
  [string]
  $ChatID = $Env:TG_CHAT_ID
)

# Apply default parameters for web requests
if ($DumplingsDefaultParameterValues) {
  $PSDefaultParameterValues = $DumplingsDefaultParameterValues
}

filter ConvertTo-TelegramEscapedText {
  $_ -creplace '([_*\[\]()~`>#+\-=|{}.!])', '\$1'
}

filter ConvertTo-TelegramEscapedCode {
  $_ -creplace '([`\\])', '\$1'
}

function Send-TelegramMessage {
  <#
  .SYNOPSIS
    Function to convert template to plain textsend message using Telegram Bot API
  #>
  param (
    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The message content to be sent'
    )]
    $Message
  )

  # Telegram has a message length limit of 4096 characters, split it by length and send them separately
  $Messages = @()
  for ($i = 0; $i -lt $Message.Length; $i += 4096) {
    $Messages += $Message.Substring($i, [System.Math]::Min(4096, $Message.Length - $i))
  }

  foreach ($Message in $Messages) {
    $Payload = @{
      chat_id                  = $ChatID
      text                     = $Message
      parse_mode               = 'MarkdownV2'
      disable_web_page_preview = $true
    }
    $Request = @{
      Uri         = "https://api.telegram.org/bot$($BotToken)/sendMessage"
      Method      = 'Post'
      Body        = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $payload -Compress))
      ContentType = 'application/json'
    }
    try {
      Invoke-WebRequest @Request
    } catch {
      Write-Log -Object "`e[1mTelegram:`e[22m An error occured while sending the message:" -Level Error
      $_ | Out-Host
    }
  }
}

Register-EngineEvent -SourceIdentifier 'DumplingsMessageSend' -Action {
  Send-TelegramMessage -Message $event.SourceArgs[0]
}

$ExecutionContext.SessionState.Module.OnRemove += { Unregister-Event -SourceIdentifier 'DumplingsMessageSend' -ErrorAction Ignore }

Export-ModuleMember -Function ConvertTo-TelegramEscapedText, ConvertTo-TelegramEscapedCode, Send-TelegramMessage
