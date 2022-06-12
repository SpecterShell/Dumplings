function Invoke-CustomWebRequest {
    <#
    .SYNOPSIS
        Invoke "Invoke-WebRequest" with custom parameters
    #>

    Invoke-WebRequest @DefaultWebRequestParameters @args
}

function Invoke-CustomRestMethod {
    <#
    .SYNOPSIS
        Invoke "Invoke-RestMethod" with custom parameters
    #>

    Invoke-RestMethod @DefaultWebRequestParameters @args
}

Export-ModuleMember -Function * -Variable *
