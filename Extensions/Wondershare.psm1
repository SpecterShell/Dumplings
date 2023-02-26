<#
.SYNOPSIS
  Invoke Wondershare's API
#>

# Apply default parameters
if ($DumplingsDefaultParameterValues) {
  $PSDefaultParameterValues = $DumplingsDefaultParameterValues
}

function Invoke-WondershareJsonUpgradeApi {
  <#
  .SYNOPSIS
    Invoke Wondershare's JSON upgrade API
  #>
  param (
    [parameter(Mandatory)]
    [int]
    $ProductId,

    [parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Version,

    [switch]
    $X86 = $false,

    [int]
    $Type = 2,

    [string]
    $Locale = 'en-US'
  )

  $Uri2 = "https://pc-api.300624.com/v${Type}/product/check-upgrade?pid=${ProductId}&client_sign={}&version=${Version}&platform=win_$($x86 ? 'x86' : 'x64')"
  if ($Type -ge 3) {
    $Params1 = @{
      Uri         = 'https://pc-api.300624.com/v3/user/client/token'
      Method      = 'Post'
      Headers     = @{
        'X-Client-Type' = 1
        'X-Client-Sn'   = '{}'
        'X-App-Key'     = '58bd26679d74e279c8421ecc.demo'
        'X-Prod-Id'     = $ProductId
        'X-Prod-Ver'    = $Version
      }
      Body        = @{
        grant_type = 'client_credentials'
        app_secret = 'Op00P1TrqfIKzM9qbo44mcIXFiOxKTRytx'
      } | ConvertTo-Json -Compress
      ContentType = 'application/json'
    }
    $Object1 = Invoke-RestMethod @Params1

    $Params2 = @{
      Uri            = $Uri2
      Authentication = 'Bearer'
      Token          = ConvertTo-SecureString -String $Object1.data.access_token -AsPlainText
    }
    $Object2 = Invoke-RestMethod @Params2
  } else {
    $Object2 = Invoke-RestMethod -Uri $Uri2
  }

  return [ordered]@{
    # Version
    Version   = $Object2.data.version
    # Installer
    Installer = @()
    # ReleaseNotes
    Locale    = @(
      [ordered]@{
        Locale = $Locale
        Key    = 'ReleaseNotes'
        Value  = $Object2.data.whats_new_content | Format-Text
      }
    )
  }
}

function Invoke-WondershareXmlUpgradeApi {
  <#
  .SYNOPSIS
    Invoke Wondershare's XML upgrade API
  #>
  param (
    [parameter(Mandatory)]
    [int]
    $ProductId,

    [parameter(Mandatory)]
    [string]
    $Version,

    [string]
    $Locale = 'en-US'
  )

  $Uri = "https://cbs.wondershare.com/go.php?m=upgrade_info&pid=${ProductId}&version=${Version}"
  $Object = [xml](Invoke-WebRequest -Uri $Uri | Read-ResponseContent)

  return [ordered]@{
    # Version
    Version   = $Object.Respone.WhatNews.Item[0].Version
    # Installer
    Installer = @()
    # ReleaseNotes
    Locale    = @(
      [ordered]@{
        Locale = $Locale
        Key    = 'ReleaseNotes'
        Value  = $Object.Respone.WhatNews.Item[0].Text.'#cdata-section' | Format-Text
      }
    )
  }
}

function Invoke-WondershareXmlDownloadApi {
  <#
  .SYNOPSIS
    Invoke Wondershare's XML download API
  #>
  param (
    [parameter(Mandatory)]
    [int]
    $ProductId,

    [string]
    $Wae
  )

  $Uri = "http://platform.wondershare.com/rest/v2/downloader/runtime/?product_id=${ProductId}&wae=${Wae}"
  $Object = Invoke-RestMethod -Uri $Uri

  return [ordered]@{
    # Version
    Version   = $Object.wsrp.downloader.runtime.version.'#cdata-section'
    # Installer
    Installer = @()
  }
}

Export-ModuleMember -Function Invoke-WondershareJsonUpgradeApi, Invoke-WondershareXmlUpgradeApi, Invoke-WondershareXmlDownloadApi
