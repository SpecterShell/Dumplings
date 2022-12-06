<#
.SYNOPSIS
  Invoke NetEase CloudMusic's Encrypted API
#>

# Apply default parameters
if ($DumplingsDefaultParameterValues) {
  $PSDefaultParameterValues = $DumplingsDefaultParameterValues
}

function Invoke-CloudMusicApi {
  <#
  .SYNOPSIS
    Invoke NetEase CloudMusic's Encrypted API
  #>
  param (
    [parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Path,

    [parameter(Mandatory)]
    [hashtable]
    $Params,

    [parameter(Mandatory)]
    [hashtable]
    $Cookies
  )

  # Initial cipher
  $AesCipher = [System.Security.Cryptography.AesManaged]@{
    Mode = [System.Security.Cryptography.CipherMode]::ECB
    Key  = [System.Text.Encoding]::UTF8.GetBytes('e82ckenh8dichen8')
  }
  $Encryptor = $AesCipher.CreateEncryptor()
  $Decryptor = $AesCipher.CreateDecryptor()

  # Hash params
  $ParamsJson = ConvertTo-Json -InputObject $Params -Compress
  $Sign = "nobody/api${Path}use${ParamsJson}md5forencrypt"
  $SignBytes = [System.Text.Encoding]::UTF8.GetBytes($Sign)
  $SignHashedBytes = [System.Security.Cryptography.MD5CryptoServiceProvider]::HashData($SignBytes)
  $SignHashed = [System.BitConverter]::ToString($SignHashedBytes).Replace('-', '').ToLower()

  # Encrypt request content
  $RequestContent = "/api${Path}-36cd479b6b5-${ParamsJson}-36cd479b6b5-${SignHashed}"
  $RequestContentBytes = [System.Text.Encoding]::UTF8.GetBytes($RequestContent)
  $RequestContentEncryptedBytes = $Encryptor.TransformFinalBlock($RequestContentBytes, 0, $RequestContentBytes.Length)
  $RequestContentEncrypted = [System.BitConverter]::ToString($RequestContentEncryptedBytes).Replace('-', '')

  # Invoke API
  $RequestParams = @{
    Method  = 'Post'
    Uri     = "https://interface.music.163.com/eapi${Path}"
    Headers = @{
      Cookie = $Cookies.GetEnumerator().ForEach({ "$($_.Name)=$($_.Value)" }) -join ';'
    }
    Body    = [System.Text.Encoding]::UTF8.GetBytes("params=$RequestContentEncrypted")
  }
  $Response = Invoke-WebRequest @RequestParams

  # Decrypt and read response content
  if ($Params.e_r) {
    $ResponseContentEncryptedBytes = $Response.RawContentStream.ToArray()
    $ResponseContentBytes = $Decryptor.TransformFinalBlock($ResponseContentEncryptedBytes, 0, $ResponseContentEncryptedBytes.Length)
    $ResponseContent = [System.Text.Encoding]::UTF8.GetString($ResponseContentBytes)
    Write-Output -InputObject ($ResponseContent | ConvertFrom-Json)
  }
  # Read response content directly
  else {
    Write-Output -InputObject ($Response.Content | ConvertFrom-Json)
  }

  # Dispose encryptor and decryptor
  $Encryptor.Dispose()
  $Decryptor.Dispose()
}

Export-ModuleMember -Function *
