# Apply default function parameters
if ($DumplingsDefaultParameterValues) { $PSDefaultParameterValues = $DumplingsDefaultParameterValues }

# Force stop on error
$ErrorActionPreference = 'Stop'

function Invoke-MatrixApi {
  <#
  .SYNOPSIS
    Invoke Matrix client API
  .LINK
    https://spec.matrix.org/latest/client-server-api/
  .PARAMETER EndPoint
    The Matrix endpoint to be invoked
  .PARAMETER Method
    The HTTP method of the HTTP request
  .PARAMETER Body
    The request body
  .PARAMETER HomeServer
    Matrix server address
  .PARAMETER Token
    Matrix client token
  #>
  param (
    [Parameter(Mandatory, HelpMessage = 'The Matrix endpoint to be invoked')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$EndPoint,

    [Parameter(Mandatory, HelpMessage = 'The HTTP method of the HTTP request')]
    [Microsoft.PowerShell.Commands.WebRequestMethod]$Method,

    [Parameter(ValueFromPipeline, HelpMessage = 'The request body')]
    [System.Collections.IDictionary]$Body,

    [Parameter(HelpMessage = 'Matrix server address')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$HomeServer = $Env:MT_HOME_SERVER ?? 'https://matrix-client.matrix.org',

    [Parameter(HelpMessage = 'Matrix client token')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Token = $Env:MT_BOT_TOKEN
  )

  $Params = @{
    Uri            = "${HomeServer}${EndPoint}"
    Method         = $Method
    Authentication = 'Bearer'
    Token          = ConvertTo-SecureString -String $Token -AsPlainText
  }
  if ($Body) {
    $Params.Body = ConvertTo-Json -InputObject $Body -Compress -EscapeHandling EscapeNonAscii
    $Params.ContentType = 'application/json'
  }
  # Transaction ID (https://spec.matrix.org/v1.9/client-server-api/#transaction-identifiers)
  if ($Method -eq 'Put' -and $Body) { $Params.Uri = "$($Params.Uri)/$([datetimeoffset]::Now.UtcTicks)" }
  Invoke-RestMethod @Params
}

function New-MatrixMessage {
  <#
  .SYNOPSIS
    Send a new message to a Matrix room
  .PARAMETER Message
    The message content to be sent
  .PARAMETER AsHtml
    Parse the message content as HTML
  .PARAMETER AsMarkdown
    Parse the message content as Markdown
  .PARAMETER RoomID
    The room ID
  .PARAMETER HomeServer
    Matrix server address
  .PARAMETER Token
    Matrix client token
  #>
  [CmdletBinding(DefaultParameterSetName = 'PlainText')]
  param (
    [Parameter(ValueFromPipeline, Mandatory, HelpMessage = 'The message content to be sent')]
    [string]$Message,

    [Parameter(DontShow, ParameterSetName = 'PlainText', HelpMessage = 'Parse the message content as plain text')]
    [switch]$AsPlainText,

    [Parameter(ParameterSetName = 'HTML', HelpMessage = 'Parse the message content as HTML')]
    [switch]$AsHtml,

    [Parameter(ParameterSetName = 'Markdown', HelpMessage = 'Parse the message content as Markdown')]
    [switch]$AsMarkdown,

    [Parameter(HelpMessage = 'The room ID')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$RoomID = $Env:MT_ROOM_ID,

    [Parameter(HelpMessage = 'Matrix Bot token')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$HomeServer = $Env:MT_HOME_SERVER ?? 'https://matrix-client.matrix.org',

    [Parameter(HelpMessage = 'Matrix Bot token')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Token = $Env:MT_BOT_TOKEN
  )

  $Params = @{
    EndPoint   = "/_matrix/client/v3/rooms/${RoomID}/send/m.room.message"
    Method     = 'Put'
    Body       = @{
      msgtype = 'm.text'
      body    = $Message
    }
    HomeServer = $HomeServer
    Token      = $Token
  }
  if ($AsHtml) {
    $Params.Body.format = 'org.matrix.custom.html'
    $Params.Body.formatted_body = $Message
    $Params.Body.body = $Params.Body.formatted_body | ConvertFrom-Html | Get-TextContent
  }
  if ($AsMarkdown) {
    $Params.Body.format = 'org.matrix.custom.html'
    # Matrix automatically inserts a line break between </p> and <p>. Replace <p> with <br>
    $Params.Body.formatted_body = ($Message | ConvertFrom-Markdown).Html -replace '<p>(.*?)</p>', '$1<br>'
    $Params.Body.body = $Params.Body.formatted_body | ConvertFrom-Html | Get-TextContent
  }
  Invoke-MatrixApi @Params
}

function Remove-MatrixMessage {
  <#
  .SYNOPSIS
    Redact a message from a room
  .PARAMETER EventID
    The ID of the event when the message was first sent
  .PARAMETER Reason
    The reason for redacting this message
  .PARAMETER RoomID
    The room ID
  .PARAMETER HomeServer
    Matrix server address
  .PARAMETER Token
    Matrix client token
  #>
  param (
    [Parameter(ValueFromPipeline, Mandatory, HelpMessage = 'The ID of the event when the message was first sent')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$EventID,

    [Parameter(HelpMessage = 'The reason for redacting this message')]
    [string]$Reason,

    [Parameter(HelpMessage = 'The room ID')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$RoomID = $Env:MT_ROOM_ID,

    [Parameter(HelpMessage = 'Matrix server address')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$HomeServer = $Env:MT_HOME_SERVER ?? 'https://matrix-client.matrix.org',

    [Parameter(HelpMessage = 'Matrix client token')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Token = $Env:MT_BOT_TOKEN
  )

  $Params = @{
    EndPoint   = "/_matrix/client/v3/rooms/${RoomID}/redact/${EventID}"
    Method     = 'Put'
    Body       = @{}
    HomeServer = $HomeServer
    Token      = $Token
  }
  if ($Reason) { $Params.Body.reason = $Reason }
  Invoke-MatrixApi @Params
}

function Update-MatrixMessage {
  <#
  .SYNOPSIS
    Update the content of an existing message in a room
  .PARAMETER Message
    The new message content to which the previous one will be updated
  .PARAMETER AsHtml
    Parse the new message as HTML
  .PARAMETER AsMarkdown
    Parse the new message as Markdown
  .PARAMETER EventID
    The ID of the event when the message was first sent
  .PARAMETER RoomID
    The room ID
  .PARAMETER HomeServer
    Matrix server address
  .PARAMETER Token
    Matrix client token
  #>
  [CmdletBinding(DefaultParameterSetName = 'PlainText')]
  param (
    [Parameter(ValueFromPipeline, Mandatory, HelpMessage = 'The new message content to which the previous one will be updated')]
    [string]$Message,

    [Parameter(DontShow, ParameterSetName = 'PlainText', HelpMessage = 'Parse the new message as plain text')]
    [switch]$AsPlainText,

    [Parameter(ParameterSetName = 'HTML', HelpMessage = 'Parse the new message as HTML')]
    [switch]$AsHtml,

    [Parameter(ParameterSetName = 'Markdown', HelpMessage = 'Parse the new message as Markdown')]
    [switch]$AsMarkdown,

    [Parameter(ValueFromPipeline, Mandatory, HelpMessage = 'The ID of the event when the message was first sent')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$EventID,

    [Parameter(HelpMessage = 'The room ID')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$RoomID = $Env:MT_ROOM_ID,

    [Parameter(HelpMessage = 'Matrix server address')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$HomeServer = $Env:MT_HOME_SERVER ?? 'https://matrix-client.matrix.org',

    [Parameter(HelpMessage = 'Matrix client token')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Token = $Env:MT_BOT_TOKEN
  )

  $Params = @{
    EndPoint   = "/_matrix/client/v3/rooms/${RoomID}/send/m.room.message"
    Method     = 'Put'
    Body       = @{
      msgtype         = 'm.text'
      body            = $Message
      'm.new_content' = @{
        msgtype      = 'm.text'
        'm.mentions' = @{}
        body         = $Message
      }
      'm.mentions'    = @{}
      'm.relates_to'  = @{
        event_id = $EventID
        rel_type = 'm.replace'
      }
    }
    HomeServer = $HomeServer
    Token      = $Token
  }
  if ($AsHtml) {
    $Params.Body.format = $Params.Body.'m.new_content'.format = 'org.matrix.custom.html'
    $Params.Body.formatted_body = $Params.Body.'m.new_content'.formatted_body = $Message
    $Params.Body.body = $Params.Body.'m.new_content'.body = $Params.Body.formatted_body | ConvertFrom-Html | Get-TextContent
  }
  if ($AsMarkdown) {
    $Params.Body.format = $Params.Body.'m.new_content'.format = 'org.matrix.custom.html'
    $Params.Body.formatted_body = $Params.Body.'m.new_content'.formatted_body = ($Message | ConvertFrom-Markdown).Html
    $Params.Body.body = $Params.Body.'m.new_content'.body = $Params.Body.formatted_body | ConvertFrom-Html | Get-TextContent
  }
  Invoke-MatrixApi @Params
}

function Send-MatrixMessage {
  <#
  .SYNOPSIS
    Send a new message or update an existing message (if the event ID for the previous message is provided) to a Matrix room through Matrix client API
  .PARAMETER Message
    The message content
  .PARAMETER AsHtml
    Parse the message as HTML
  .PARAMETER AsMarkdown
    Parse the message as Markdown
  .PARAMETER EventID
    The ID of the event when the message was first sent
  .PARAMETER RoomID
    The room ID
  .PARAMETER HomeServer
    Matrix server address
  .PARAMETER Token
    Matrix client token
  .OUTPUTS
    The event ID
  #>
  [CmdletBinding(DefaultParameterSetName = 'PlainText')]
  [OutputType([string])]
  param (
    [Parameter(ValueFromPipeline, Mandatory, HelpMessage = 'The message content')]
    [string]$Message,

    [Parameter(DontShow, ParameterSetName = 'PlainText', HelpMessage = 'Parse the new message as plain text')]
    [switch]$AsPlainText,

    [Parameter(ParameterSetName = 'HTML', HelpMessage = 'Parse the new message as HTML')]
    [switch]$AsHtml,

    [Parameter(ParameterSetName = 'Markdown', HelpMessage = 'Parse the new message as Markdown')]
    [switch]$AsMarkdown,

    [Parameter(HelpMessage = 'The ID of the event when the message was first sent')]
    [string]$EventID,

    [Parameter(HelpMessage = 'The room ID')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$RoomID = $Env:MT_ROOM_ID,

    [Parameter(HelpMessage = 'Matrix server address')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$HomeServer = $Env:MT_HOME_SERVER ?? 'https://matrix-client.matrix.org',

    [Parameter(HelpMessage = 'Matrix client token')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Token = $Env:MT_BOT_TOKEN
  )

  $Params = @{
    Message    = $Message
    RoomID     = $RoomID
    HomeServer = $HomeServer
    Token      = $Token
  }
  if ($AsHtml) { $Params.AsHtml = $true }
  if ($AsMarkdown) { $Params.AsMarkdown = $true }

  if ($EventID) {
    $Response = Update-MatrixMessage @Params -EventID $EventID
    # Message updating only works on the original event ID
    return $EventID
  } else {
    $Response = New-MatrixMessage @Params
    return $Response.event_id
  }
}

Export-ModuleMember -Function *
