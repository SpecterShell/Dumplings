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

function Invoke-TelegramApi {
  <#
  .SYNOPSIS
    Function to invoke Telegram Bot API
  #>
  param (
    [Parameter(
      HelpMessage = 'Telegram Bot token'
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $Token = $Env:TG_BOT_TOKEN,

    [Parameter(
      Mandatory,
      HelpMessage = 'The method of the request'
    )]
    [string]
    $Method,

    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The body of the request'
    )]
    [System.Collections.IDictionary]
    $Body
  )

  $Params = @{
    Uri         = "https://api.telegram.org/bot${Token}/${Method}"
    Method      = 'Post'
    Body        = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $Body -Compress -EscapeHandling EscapeNonAscii))
    ContentType = 'application/json'
  }
  Invoke-RestMethod @Params
}

function New-TelegramMessage {
  <#
  .SYNOPSIS
    Function to send message to telegram using Telegram Bot API
  #>
  param (
    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The message content to be sent'
    )]
    [string]
    $Message,

    [Parameter(
      HelpMessage = 'Telegram Bot token'
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $Token = $Env:TG_BOT_TOKEN,

    [Parameter(
      HelpMessage = 'Telegram Chat ID'
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $ChatID = $Env:TG_CHAT_ID
  )

  Invoke-TelegramApi -Token $Token -Method 'sendMessage' -Body @{
    chat_id                  = $ChatID
    text                     = $Message
    parse_mode               = 'MarkdownV2'
    disable_web_page_preview = $true
  }
}

function Remove-TelegramMessage {
  <#
  .SYNOPSIS
    Function to remove message on telegram using Telegram Bot API
  #>
  param (
    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The ID of messages to be deleted'
    )]
    [int]
    $MessageID,

    [Parameter(
      HelpMessage = 'Telegram Bot token'
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $Token = $Env:TG_BOT_TOKEN,

    [Parameter(
      HelpMessage = 'Telegram Chat ID'
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $ChatID = $Env:TG_CHAT_ID
  )

  Invoke-TelegramApi -Token $Token -Method 'deleteMessage' -Body @{
    chat_id    = $ChatID
    message_id = $ID
  }
}

function Update-TelegramMessage {
  <#
  .SYNOPSIS
    Function to update message on telegram using Telegram Bot API
  #>
  param (
    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The message content the previous ones will be updated to'
    )]
    [string]
    $Message,

    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The ID of messages to be updated'
    )]
    [int]
    $MessageID,

    [Parameter(
      HelpMessage = 'Telegram Bot token'
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $Token = $Env:TG_BOT_TOKEN,

    [Parameter(
      HelpMessage = 'Telegram Chat ID'
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $ChatID = $Env:TG_CHAT_ID
  )

  Invoke-TelegramApi -Token $Token -Method 'editMessageText' -Body @{
    chat_id                  = $ChatID
    message_id               = $MessageID
    text                     = $Message
    parse_mode               = 'MarkdownV2'
    disable_web_page_preview = $true
  }
}

function Send-TelegramMessage {
  <#
  .SYNOPSIS
    Function to send message to telegram using Telegram Bot API
  #>
  param (
    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The message content to be sent'
    )]
    [string]
    $Message,

    [Parameter(
      ValueFromPipeline,
      HelpMessage = 'The ID of messages to be updated'
    )]
    [int[]]
    $MessageID = [int[]]@(),

    [Parameter(
      HelpMessage = 'Telegram Bot token'
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $Token = $Env:TG_BOT_TOKEN,

    [Parameter(
      HelpMessage = 'Telegram Chat ID'
    )]
    [ValidateNotNullOrEmpty()]
    [string]
    $ChatID = $Env:TG_CHAT_ID
  )

  # Telegram has a message length limit of 4096 characters, split it by length and send them separately
  $Messages = @()
  for ($i = 0; $i -lt $Message.Length; $i += 4096) {
    $Messages += $Message.Substring($i, [System.Math]::Min(4096, $Message.Length - $i))
  }

  $Responses = @()
  if ($MessageID.Count -eq 0) {
    foreach ($Message in $Messages) {
      $Responses += New-TelegramMessage -Message $Message -Token $Token -ChatID $ChatID
    }
  } elseif ($MessageID.Count -gt 0 -and $Messages.Count -eq $MessageID.Count) {
    for ($i = 0; $i -lt $MessageID.Count; $i++) {
      $Responses += Update-TelegramMessage -Message $Messages[$i] -MessageID $MessageID[$i] -Token $Token -ChatID $ChatID
    }
  } elseif ($MessageID.Count -gt 0 -and $Messages.Count -ne $MessageID.Count) {
    foreach ($ID in $MessageID) {
      Remove-TelegramMessage -MessageID $MessageID -Token $Token -ChatID $ChatID | Out-Null
    }
    foreach ($Message in $Messages) {
      $Responses += New-TelegramMessage -Message $Message -Token $Token -ChatID $ChatID
    }
  }
  return $Responses
}

Export-ModuleMember -Function *
