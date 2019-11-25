### This will create a new company and user in Cloudberry based on your customer's business name, and 
### the user based on the customer's primary contact name and email with a randomly generated password.
### The new Account ID and User ID will be saved to the asset under two custom asset 
### fields "Cloudberry_Company_ID" and "Cloudberry_User_ID"
### A new Baremetal backup plan is created, that will automatically run at 11pm every night.
###
### 1. Create two new custom asset Text Fields in the Syncro Asset type: Cloudberry_Company_ID and Cloudberry_User_ID
### 2. Add your installer .exe to your Script Files. It MUST be named backup-installer.exe
### 3. Key in your Syncro subdomain for the $subdomain variable
### 4. Enter your API username for the $authUserName variable
### 5. Enter your API password for the $authPass variable
###
### Doesn't parse Storage Limit accounts to grab the ID.  Quickest way I know is to 
### Edit a user on msbackups.com, Edit the Backup Destination,
### on the Storage Limit drop-down, right-click the field and choose Inspect (Chrome), drop-down 
### the element that's highlighted, and your
### Storage Limit IDs should now be visible in the HTML, 
### like this:  <option value="12345">Server 500GB</option>.  12345 would be your cbPackageID
###
### Help Setting Up Your API Credentials
### https://mspbackups.com/Admin/Help.aspx?c=Contents%2Fhelp_MBS_API_2.0.html#creds

Import-Module $env:SyncroModule -DisableNameChecking

######################### ENTER YOUR INFO HERE #########################
$subdomain = "YOUR_SUBDOMAIN_HERE"

# CB API Credentials
$authUserName = 'YOUR_API_USERNAME_HERE'
$authPass = 'YOUR_API_PASSWORD_HERE'

# CB Storage Limit Package ID
$cbPackageId = 'YOUR_PACKAGE_ID_HERE'

# CB Backup Edition (baremetal or desktop. You can also use mssql, msexchange, mssqlexchange, ultimate, vmedition)
$backupEdition = 'baremetal'

# Time you want the backup to run.  Currently set to 23:00 or 11:00pm
$backupTime = '23:00'

######################## EDIT THESE VARIABLES ONLY IF YOU WANT TO ########################
# CB Agent Info
$whitelabelProductName = "Online Backup"  #This is the brand name of your cloud-backup service you're providing to your customers
$backupPlanName = "Cloud $backupEdition Backups"  #This is the name you want to give your backup plan
$whitelabelCompanyName = "$syncro_account_name"
$pathToCbb = "C:\Program Files\$whitelabelCompanyName\$whitelabelProductName"
$tmpTextFile = "C:\temp\cbb_accounts.txt"
#####################################################################################################
######################## YOU SHOULD NOT HAVE TO EDIT ANYTHING PAST THIS LINE ########################
#####################################################################################################

######################### Random Password Generator #########################
function Get-RandomCharacters($length, $characters) {
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs=""
    return [String]$characters[$random]
}
 
function Switch-PassLetters([string]$inputString){     
    $characterArray = $inputString.ToCharArray()   
    $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
    $randomPassOutputString = -join $scrambledStringArray
    return $randomPassOutputString 
}
 
$randomPassword = Get-RandomCharacters -length 4 -characters 'abcdefghiklmnoprstuvwxyz'
$randomPassword += Get-RandomCharacters -length 4 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
$randomPassword += Get-RandomCharacters -length 4 -characters '1234567890'
$randomPassword += Get-RandomCharacters -length 4 -characters '!%&/<>=?^-_+'
 
$randomPassword = Switch-PassLetters $randomPassword

######################### Setup Company and User in Cloudberry #########################

#### CB API URLS ####
$cbLoginUri = 'https://api.mspbackups.com/api/Provider/Login'
$cbCompanyUri = 'https://api.mspbackups.com/api/Companies'
$cbUserUri = 'https://api.mspbackups.com/api/Users'
$cbAccountsUri = 'https://api.mspbackups.com/api/Accounts'

#### Token ####
# Token Auth
$tokenAuth = @{
    UserName="$authUserName"
    Password="$authPass"
}
#Convert to JSON
$tokenAuthJson = $tokenAuth | ConvertTo-Json

# Token URI
$tokenParams = @{
    Uri = $cbLoginUri
    Method = 'POST'
    Body = $tokenAuthJson
    ContentType = 'application/json'
}

# Grab API Token Info
$tokenResponse = Invoke-RestMethod @tokenParams

# Extract Only Token
$tokenOutput = Write-Output $tokenResponse.access_token

Start-Sleep -Seconds 3

#### Storage Accounts ####
# CB Accounts URI
$cbAccountsParams = @{
    Uri = $cbAccountsUri
    Headers = @{ 'Authorization' = "Bearer $tokenOutput"}
    Method = 'GET'
    ContentType = 'application/json'
}

$cbAccountsOutput = Invoke-RestMethod @cbAccountsParams

# Grab Destination List for New User Account
$cbAccountsAccountID = $cbAccountsOutput.AccountID
$cbAccountsDestinations = $cbAccountsOutput.Destinations.Destination

######################## Query or Create New Company and Users ######################
#### Query for existing Company and User ####
# Company Query
$cbCompanyListQuery = @{
    Uri = $cbCompanyUri
    Headers = @{ 'Authorization' = "Bearer $tokenOutput"}
    Method = 'GET'
    ContentType = 'application/json'
}

$cbCompanyListOutput = Invoke-RestMethod @cbCompanyListQuery 

$cbCompanyListOutputTable = $cbCompanyListOutput | Where-Object { $_.Name -eq "$customer_business_name_or_customer_full_name"}

$cbCompanyListOutputTableId = $cbCompanyListOutputTable.Id

#### Create New Company IF NULL ####
$cbCompanyId = if (!$cbCompanyListOutputTableId){
    # Customer Business Name Fields
    $customer_business_name = @{
    Name="$customer_business_name_or_customer_full_name"
    LicenseSettings='2'
    }

    # Convert to JSON
    $companyJsonBody = $customer_business_name | ConvertTo-Json

    # Business Name URI
    $companyParams = @{
        Uri = $cbCompanyUri
        Headers = @{ 'Authorization' = "Bearer $tokenOutput"}
        Method = 'POST'
        Body = $companyJsonBody
        ContentType = 'application/json'
    }

    # Create Company
    Invoke-RestMethod @companyParams
}
else {
    $cbCompanyListOutputTableId
}

Start-Sleep -Seconds 3

#### Query for existing User ####
$cbUserListQuery = @{
    Uri = $cbUserUri
    Headers = @{ 'Authorization' = "Bearer $tokenOutput"}
    Method = 'GET'
    ContentType = 'application/json'
}

$cbUserListOutput = Invoke-RestMethod @cbUserListQuery 

$cbUserListOutputTable = $cbUserListOutput | Where-Object { $_.Email -eq "$customer_email"}

$cbUserListOutputTableId = $cbUserListOutputTable.Id

#### Create New User IF NULL ####
$cbUserId = if (!$cbUserListOutputTableId){
    # Customer User Fields
    $customer_user_name = [ordered]@{
    Email="$customer_email"
    Company="$customer_business_name_or_customer_full_name"
    FirstName="$customer_full_name"
    Enabled='true'
    Password="$randomPassword"
    DestinationList= ,@{
        AccountID="$cbAccountsAccountId"
        Destination="$cbAccountsDestinations"
        PackageID="$cbPackageId"
    }
    SendEmailInstruction='false'
    }

    #Convert to JSON
    $userJsonBody = $customer_user_name | ConvertTo-Json

    # User Name URI
    $userParams = @{
        Uri = $cbUserUri
        Headers = @{ 'Authorization' = "Bearer $tokenOutput"}
        Method = 'POST'
        Body = $userJsonBody
        ContentType = 'application/json'
    }

    # Create User
    Invoke-RestMethod @userParams
}
else {
    $cbUserListOutputTableId
}

Start-Sleep -Seconds 3

#### Update Existing User Password ####
$updateUserPasswordFields = @{
    ID="$cbUserId"
    Enabled='true'
    Password="$randomPassword"
}

# Convert to JSON
$updateUserPasswordJsonBody = $updateUserPasswordFields | ConvertTo-Json

# User Password Update URI
$updateUserPasswordParams = @{
    Uri = $cbUserUri
    Headers = @{ 'Authorization' = "Bearer $tokenOutput"}
    Method = 'PUT'
    Body = $updateUserPasswordJsonBody
    ContentType = 'application/json'
}

# Update User Password
$updateUserPassword = Invoke-RestMethod @updateUserPasswordParams
$updateUserPassword
######################### Install Cloudberry Agent #########################

# Send silent installer command to start
& "C:\temp\backup-installer.exe" /S 2>&1
Start-Sleep -Milliseconds 300

while(Get-Process backup-installer -ErrorAction SilentlyContinue)
{
    write-host "Waiting for install to finish..."
    Start-Sleep -Seconds 10
}

# We are going to grab the first storage account and use it
& "$pathToCbb\cbb.exe" option -edition $backupEdition 2>&1
& "$pathToCbb\cbb.exe" addAccount -e $customer_email -p $randomPassword 2>&1
& "$pathToCbb\cbb.exe" account -l > $tmpTextFile 2>&1

Write-Host "Ok, its installed! Now we just gotta setup the plans!"

$accounts = Get-Content $tmpTextFile
[regex]$regex = '\w+-\w+-\w+-\w+-\w+'
$cbStorageAccountID = $regex.Matches(($accounts | select-string -pattern "Space used")).Value

# Create backup plan
& "$pathToCbb\cbb.exe" addBackupIBBPlan -n "$backupPlanName" -aid "$cbStorageAccountId" -r -winLog on -every day -at "$backupTime" 2>&1

#### Send IDs to Customer Fields in Syncro and upload text file to Asset ####
Set-Asset-Field -Subdomain $subdomain -Name "Cloudberry_Company_ID" -Value $cbCompanyId
Set-Asset-Field -Subdomain $subdomain -Name "Cloudberry_User_ID" -Value $cbUserId

Upload-File -Subdomain "$subdomain" -FilePath "$tmpTextFile"

Write-Host "Cleaning up.."

Remove-Item -LiteralPath "$tmpTextFile"
Remove-Item -LiteralPath C:\temp\backup-installer.exe

Write-Host "Nice! Now you have a backup plan!"
