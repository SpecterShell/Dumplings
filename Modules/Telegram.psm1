param (
  [Parameter(
    Mandatory,
    HelpMessage = 'Telegram Bot token'
  )]
  [ValidateNotNullOrEmpty()]
  [string]
  $BotToken,

  [Parameter(
    Mandatory,
    HelpMessage = 'Telegram Chat ID'
  )]
  [ValidateNotNullOrEmpty()]
  [string]
  $ChatID
)

# Apply default parameters for web requests
if ($DefaultWebRequestParameters) {
  $PSDefaultParameterValues = $DefaultWebRequestParameters
}

filter ConvertTo-EscapedText {
  $_ -creplace '([_*\[\]()~`>#+\-=|{}.!])', '\$1'
}

filter ConvertTo-EscapedCode {
  $_ -creplace '([`\\])', '\$1'
}

function ConvertTo-PlainText {
  param (
    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The message hashtable to be converted to plain text'
    )]
    [System.Collections.IDictionary]
    $Message
  )

  $Content = ''
  if ($Message.Title) {
    $Content += "*$($Message.Title | ConvertTo-EscapedText)*"
  }
  if ($Message.Subtitle) {
    $Content += "`n$($Message.Subtitle | ConvertTo-EscapedText)"
  }
  $Content += "`n"
  foreach ($Entry in $Message.Entries.GetEnumerator()) {
    if ($Entry.Value) {
      $Content += "`n*$($Entry.Key | ConvertTo-EscapedText):* "
      if ($Entry.Value.Contains("`n")) {
        $Content += "`n$($Entry.Value | ConvertTo-EscapedText)"
      } else {
        $Content += "``$($Entry.Value | ConvertTo-EscapedCode)``"
      }
    }
  }

  return $Content
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

  if ($Message -is [System.Collections.IDictionary]) {
    $Message = ConvertTo-PlainText -Message $Message
  } else {
    $Message = $Message | ConvertTo-EscapedText
  }

  $Message -creplace '\\(.)', '$1' -creplace '\*+', '**' -creplace '\n+', "`n`n" | Show-Markdown | Out-Host

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
      Write-Host -Object "Telegram: ${_}" -ForegroundColor Yellow
    }
  }
}

$DumplingsMessageCount = 0

Register-EngineEvent -SourceIdentifier 'DumplingsMessageSend' -Action {
  $MutexCount = [System.Threading.Mutex]::new($false, 'DumplingsMessageMutexCount')
  $MutexExit = [System.Threading.Semaphore]::new(1, 1, 'DumplingsMessageMutexExit')

  $MutexCount.WaitOne() | Out-Null
  if ($DumplingsMessageCount -eq 0) {
    $MutexExit.WaitOne()
  }
  $DumplingsMessageCount++
  $MutexCount.ReleaseMutex() | Out-Null

  Send-TelegramMessage -Message $event.SourceArgs[0]

  $MutexCount.WaitOne() | Out-Null
  $DumplingsMessageCount--
  if ($DumplingsMessageCount -eq 0) {
    $MutexExit.Release() | Out-Null
  }
  $MutexCount.ReleaseMutex() | Out-Null
}

Register-EngineEvent -SourceIdentifier 'DumplingsTaskFinished' -Action {
  $MutexExit = [System.Threading.Semaphore]::new(1, 1, 'DumplingsMessageMutexExit')

  $MutexExit.WaitOne(9000) | Out-Null

  New-Event -SourceIdentifier 'DumplingsMessageFinished' -Sender 'DumplingsMessage'

  $MutexExit.Release() | Out-Null
}

Export-ModuleMember -Function Send-TelegramMessage -Variable DumplingsMessageCount
