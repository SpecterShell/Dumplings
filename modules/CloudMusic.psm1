# Apply default parameters for most web requests if exists
if ($DefaultWebRequestParameters) {
    $PSDefaultParameterValues = $DefaultWebRequestParameters
}

function Invoke-CloudMusicApi {
    <#
    .SYNOPSIS
        Invoke NetEase CloudMusic's Encrypted API
    #>
    param (
        [parameter(Mandatory)]
        [string]
        $Path,

        [parameter(Mandatory)]
        [hashtable]
        $Params,

        [hashtable]
        $Cookies = @{
            appver  = '0.0'
            MUSIC_A = '15e860272ed0803ccf979188982b610ab086a424d18df0f04ee8b1d194962355ef2ae33b30bb5917c514d981210de4857a446f6ceddb779fec58efb075f2174dcb7ce23cca3bd6be03a4f1d7e1fccdebb72149bd3b14523943124f3fcebe94e446b14e3f0c3f8af94212382188fe1965'
        }
    )

    # Initial cipher
    $AesCipher = [System.Security.Cryptography.AesManaged]::Create()
    $AesCipher.Mode = [System.Security.Cryptography.CipherMode]::ECB
    $AesCipher.Key = [System.Text.Encoding]::UTF8.GetBytes('e82ckenh8dichen8')
    $Encryptor = $AesCipher.CreateEncryptor()
    $Decryptor = $AesCipher.CreateDecryptor()

    # Hash params
    $ParamsJson = ConvertTo-Json -InputObject $Params -Compress
    $Sign = "nobody${Path}use${ParamsJson}md5forencrypt"
    $SignBytes = [System.Text.Encoding]::UTF8.GetBytes($Sign)
    $SignHashedBytes = [System.Security.Cryptography.MD5CryptoServiceProvider]::HashData($SignBytes)
    $SignHashed = [System.BitConverter]::ToString($SignHashedBytes).Replace('-', '').ToLower()

    # Encrypt request content
    $RequestContent = "${Path}-36cd479b6b5-${ParamsJson}-36cd479b6b5-$SignHashed"
    $RequestContentBytes = [System.Text.Encoding]::UTF8.GetBytes($RequestContent)
    $RequestContentEncryptedBytes = $Encryptor.TransformFinalBlock($RequestContentBytes, 0, $RequestContentBytes.Length)
    $RequestContentEncrypted = [System.BitConverter]::ToString($RequestContentEncryptedBytes).Replace('-', '')

    # Invoke API
    $RequestParams = @{
        Method  = 'Post'
        Uri     = "https://interface.music.163.com/$($Path.Replace('/api', 'eapi'))"
        Headers = @{
            Cookie = $Cookies.GetEnumerator().ForEach({ "$($_.Name)=$($_.Value)" }) -join ';'
        }
        Body    = [System.Text.Encoding]::UTF8.GetBytes("params=$RequestContentEncrypted")
    }
    $Response = Invoke-WebRequest @RequestParams

    # Decrypt and read response content
    if ($Params.e_r) {
        $ResponseContentBytes = $Response.RawContentStream.ToArray()
        $ResponseContentDecryptedBytes = $Decryptor.TransformFinalBlock($ResponseContentBytes, 0, $ResponseContentBytes.Length)
        Write-Output -InputObject ([System.Text.Encoding]::UTF8.GetString($ResponseContentDecryptedBytes) | ConvertFrom-Json)
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
