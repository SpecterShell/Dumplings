$Config = @{
    'Identifier' = 'Xiaoe.Xiaoetong'
    'Skip'       = $false
}

$Uri1 = 'https://class-server.xiaoeknow.com/client/xe.big_class.client.check_version?sv=Windows&sw=0&dn=0'

$Fetch = {
    $Object1 = Invoke-RestMethod -Uri $Uri1 -Method Post

    $Uri2 = "$($Object1.data.url)/latest.yml"
    $Prefix = "$($Object1.data.url)/"
    $Result = Invoke-RestMethod -Uri $Uri2 | ConvertFrom-ElectronUpdater -Prefix $Prefix

    $ReleaseNotes = $Object1.data.remark -creplace '<p>(.+?)</p>', "`$1`n" | Format-Text
    Add-Member -MemberType NoteProperty -Name 'ReleaseNotes' -Value $ReleaseNotes -InputObject $Result

    return $Result
}

Export-ModuleMember -Variable Config, Fetch
