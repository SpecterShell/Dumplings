# Apply default function parameters
if ($DumplingsDefaultParameterValues) { $PSDefaultParameterValues = $DumplingsDefaultParameterValues }

# Force stop on error
$ErrorActionPreference = 'Stop'

filter ConvertTo-TelegramEscapedText {
  $_ -replace '([_*\[\]()~`>#+\-=|{}.!\\])', '\$1'
}

filter ConvertTo-TelegramEscapedCode {
  $_ -replace '([`\\])', '\$1'
}

function Invoke-TelegramApi {
  <#
  .SYNOPSIS
    Invoke Telegram bot API
  .LINK
    https://core.telegram.org/bots/api
  .PARAMETER Method
    The Telegram method to be invoked, e.g., sendMessage
  .PARAMETER Body
    The request body
  .PARAMETER Token
    Telegram bot token
  #>
  param (
    [Parameter(Mandatory, HelpMessage = 'The Telegram method to be invoked, e.g., sendMessage')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Method,

    [Parameter(ValueFromPipeline, Mandatory, HelpMessage = 'The request body')]
    [System.Collections.IDictionary]$Body,

    [Parameter(HelpMessage = 'Telegram bot token')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Token = $Env:TG_BOT_TOKEN
  )

  $Params = @{
    Uri                = "https://api.telegram.org/bot${Token}/${Method}"
    Method             = 'Post'
    Body               = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $Body -Compress -EscapeHandling EscapeNonAscii))
    ContentType        = 'application/json'
    SkipHttpErrorCheck = $true
  }
  Invoke-RestMethod @Params
}

function New-TelegramMessage {
  <#
  .SYNOPSIS
    Send a new message to a Telegram user or a Telegram group chat
  .PARAMETER Message
    The message content to be sent
  .PARAMETER AsHtml
    Parse the message content as HTML
  .PARAMETER AsMarkdown
    Parse the message content as Markdown (Telegram format, see https://core.telegram.org/bots/api#markdownv2-style)
  .PARAMETER ChatID
    The ID of the group chat or the user
  .PARAMETER Token
    Telegram bot token
  #>
  [CmdletBinding(DefaultParameterSetName = 'PlainText')]
  param (
    [Parameter(ValueFromPipeline, Mandatory, HelpMessage = 'The message content to be sent')]
    [string]$Message,

    [Parameter(DontShow, ParameterSetName = 'PlainText', HelpMessage = 'Parse the message content as plain text')]
    [switch]$AsPlainText,

    [Parameter(ParameterSetName = 'HTML', HelpMessage = 'Parse the message content as HTML')]
    [switch]$AsHtml,

    [Parameter(ParameterSetName = 'Markdown', HelpMessage = 'Parse the message content as Markdown (Telegram format)')]
    [switch]$AsMarkdown,

    [Parameter(HelpMessage = 'The ID of the group chat or the user')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ChatID = $Env:TG_CHAT_ID,

    [Parameter(HelpMessage = 'Telegram bot token')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Token = $Env:TG_BOT_TOKEN
  )

  $Params = @{
    Method = 'sendMessage'
    Body   = @{
      chat_id                  = $ChatID
      text                     = $Message
      disable_web_page_preview = $true
    }
    Token  = $Token
  }
  if ($AsHtml) { $Params.Body.parse_mode = 'HTML' }
  if ($AsMarkdown) { $Params.Body.parse_mode = 'MarkdownV2' }
  Invoke-TelegramApi @Params
}

function Remove-TelegramMessage {
  <#
  .SYNOPSIS
    Delete a message from a chat
  .PARAMETER MessageID
    The ID of the messages to be deleted
  .PARAMETER ChatID
    The ID of the group chat or the user
  .PARAMETER Token
    Telegram bot token
  #>
  param (
    [Parameter(ValueFromPipeline, Mandatory, HelpMessage = 'The ID of the messages to be deleted')]
    [int]$MessageID,

    [Parameter(HelpMessage = 'The ID of the group chat or the user')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ChatID = $Env:TG_CHAT_ID,

    [Parameter(HelpMessage = 'Telegram bot token')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Token = $Env:TG_BOT_TOKEN
  )

  $Params = @{
    Method = 'deleteMessage'
    Body   = @{
      chat_id    = $ChatID
      message_id = $ID
    }
    Token  = $Token
  }
  Invoke-TelegramApi @Params
}

function Update-TelegramMessage {
  <#
  .SYNOPSIS
    Update the content of an existing message in a chat
  .PARAMETER Message
    The new message content to which the previous one will be updated
  .PARAMETER AsHtml
    Parse the new message as HTML
  .PARAMETER AsMarkdown
    Parse the new message as Markdown (Telegram format, see https://core.telegram.org/bots/api#markdownv2-style)
  .PARAMETER MessageID
    The ID of the message to be updated
  .PARAMETER ChatID
    The ID of the group chat or the user
  .PARAMETER Token
    Telegram bot token
  #>
  [CmdletBinding(DefaultParameterSetName = 'PlainText')]
  param (
    [Parameter(ValueFromPipeline, Mandatory, HelpMessage = 'The new message content to which the previous one will be updated')]
    [string]$Message,

    [Parameter(DontShow, ParameterSetName = 'PlainText', HelpMessage = 'Parse the new message content as plain text')]
    [switch]$AsPlainText,

    [Parameter(ParameterSetName = 'HTML', HelpMessage = 'Parse the new message content as HTML')]
    [switch]$AsHtml,

    [Parameter(ParameterSetName = 'Markdown', HelpMessage = 'Parse the new message content as Markdown (Telegram format)')]
    [switch]$AsMarkdown,

    [Parameter(Mandatory, ValueFromPipeline, HelpMessage = 'The ID of the message to be updated')]
    [int]$MessageID,

    [Parameter(HelpMessage = 'The ID of the group chat or the user')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ChatID = $Env:TG_CHAT_ID,

    [Parameter(HelpMessage = 'Telegram bot token')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Token = $Env:TG_BOT_TOKEN
  )

  $Params = @{
    Method = 'editMessageText'
    Body   = @{
      chat_id                  = $ChatID
      message_id               = $MessageID
      text                     = $Message
      disable_web_page_preview = $true
    }
    Token  = $Token
  }
  if ($AsHtml) { $Params.Body.parse_mode = 'HTML' }
  if ($AsMarkdown) { $Params.Body.parse_mode = 'MarkdownV2' }
  Invoke-TelegramApi @Params
}

function Send-TelegramMessage {
  <#
  .SYNOPSIS
    Send new messages or update existing messages (if the IDs of the previous messages are provided) to a Telegram chat through Telegram bot API
  .PARAMETER Message
    The message content
  .PARAMETER AsHtml
    Parse the message as HTML
  .PARAMETER AsMarkdown
    Parse the message as Markdown (Telegram format, see https://core.telegram.org/bots/api#markdownv2-style)
  .PARAMETER MessageID
    The ID of the message to be updated
  .PARAMETER ChatID
    The ID of the group chat or the user
  .PARAMETER Token
    Telegram bot token
  .OUTPUTS
    The IDs of the messages
  #>
  [CmdletBinding(DefaultParameterSetName = 'PlainText')]
  [OutputType([System.Collections.Generic.IEnumerable[int]])]
  param (
    [Parameter(ValueFromPipeline, Mandatory, HelpMessage = 'The message content')]
    [string]$Message,

    [Parameter(DontShow, ParameterSetName = 'PlainText', HelpMessage = 'Parse the message content as plain text')]
    [switch]$AsPlainText,

    [Parameter(ParameterSetName = 'HTML', HelpMessage = 'Parse the message content as HTML')]
    [switch]$AsHtml,

    [Parameter(ParameterSetName = 'Markdown', HelpMessage = 'Parse the message content as Markdown (Telegram format, see https://core.telegram.org/bots/api#markdownv2-style)')]
    [switch]$AsMarkdown,

    [Parameter(HelpMessage = 'The ID of messages to be updated')]
    [int[]]$MessageID = [int[]]@(),

    [Parameter(HelpMessage = 'The ID of the group chat or the user')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ChatID = $Env:TG_CHAT_ID,

    [Parameter(HelpMessage = 'Telegram bot token')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Token = $Env:TG_BOT_TOKEN
  )

  $Params = @{ Token = $Token }
  if ($AsHtml) { $Params.AsHtml = $true }
  if ($AsMarkdown) { $Params.AsMarkdown = $true }

  # Telegram has a message length limit of 4096 characters, split it by length and send them separately
  $Messages = [System.Collections.Generic.List[string]]::new()
  $Cursor = 0
  while ($Cursor -lt $Message.Length) {
    $Window = [System.Math]::Min(4096, $Message.Length - $Cursor)
    # In HTML and Markdown formats, avoid cutting on the escape character at the end of the window by reducing the window size
    while (($AsHtml -or $AsMarkdown) -and $Message[$Cursor + $Window - 1] -eq '\' -and $Window -gt 0) {
      $Window--
    }
    # Restore the window size if it is currently 0 (This could happen if the message content is full of "\")
    if ($Window -eq 0) { $Window = [System.Math]::Min(4096, $Message.Length - $Cursor) }
    $Messages.Add($Message.Substring($Cursor, $Window))
    $Cursor += $Window
  }

  $IDs = [System.Collections.Generic.List[int]]::new()
  if ($MessageID.Count -eq 0) {
    # If no message ID is provided, send new messages directly
    foreach ($Message in $Messages) {
      $Response = New-TelegramMessage @Params -Message $Message -ChatID $ChatID
      if ($Response.ok -eq $false) {
        throw "$($Response.error_code) $($Response.description)"
      }
      $IDs.Add($Response.result.message_id)
    }
  } elseif ($MessageID.Count -gt 0 -and $Messages.Count -eq $MessageID.Count) {
    # If message IDs are provided and the numbers of the old messages and the new messages are equal, update the messages directly
    for ($i = 0; $i -lt $MessageID.Count; $i++) {
      $Response = Update-TelegramMessage @Params -Message $Messages[$i] -MessageID $MessageID[$i] -ChatID $ChatID
      if ($Response.ok -eq $false) {
        # Telegram API will throw an error if the new message content is the same as the old one
        # Here we ignore this kind of error and add the original message ID
        if ($Response.error_code -ne 400) {
          throw "$($Response.error_code) $($Response.description)"
        } else {
          $IDs.Add($MessageID[$i])
        }
      } else {
        $IDs.Add($Response.result.message_id)
      }
    }
  } else {
    # If message IDs are provided and the numbers of the old messages and the new messages are not equal, remove the old ones first and then send the new ones to keep messages consistent
    foreach ($ID in $MessageID) {
      $Response = Remove-TelegramMessage -MessageID $ID -ChatID $ChatID -Token $Token
      if ($Response.ok -eq $false) {
        throw "$($Response.error_code) $($Response.description)"
      }
    }
    foreach ($Message in $Messages) {
      $Response = New-TelegramMessage @Params -Message $Message -ChatID $ChatID
      if ($Response.ok -eq $false) {
        throw "$($Response.error_code) $($Response.description)"
      }
      $IDs.Add($Response.result.message_id)
    }
  }
  return $IDs
}

Export-ModuleMember -Function *
