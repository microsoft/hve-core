Write-Host "Obtain access token for Service Principal"

$accessToken = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query "accessToken" --output tsv




Write-Host "Get AAD Service Principal ID for marketplace"

$apiVersion = "7.1-preview.3"

$uri = "https://app.vssps.visualstudio.com/_apis/profile/profiles/me?api-version=${apiVersion}"

$headers = @{

    Accept = "application/json"

    Authorization = "Bearer $accessToken"

}

$spId = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get | Select-Object -ExpandProperty id

Write-Host "Service Principal ID: $spId"