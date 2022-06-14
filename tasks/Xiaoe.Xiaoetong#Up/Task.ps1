$Config = @{
    Identifier = 'Xiaoe.Xiaoetong'
    Skip       = $false
    Notes      = '升级源'
}

$Ping = {
    $Uri1 = 'https://class-server.xiaoeknow.com/client/xe.big_class.client.check_version?sv=Windows&sw=0&dn=0'
    $Object1 = Invoke-RestMethod -Uri $Uri1 -Method Post

    $Uri2 = $Object1.data.url + '/latest.yml'
    $Prefix = $Object1.data.url + '/'

    $Result = Invoke-RestMethod -Uri $Uri2 | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

    # ReleaseNotes
    $Result.ReleaseNotes = $Object1.data.remark -creplace '<p>(.+?)</p>', "`$1`n" | Format-Text

    return $Result
}

return @{
    Config = $Config
    Ping   = $Ping
}
