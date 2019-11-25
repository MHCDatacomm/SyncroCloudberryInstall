# SyncroCloudberryInstall
Installs Cloudberry (MSP 360) from Syncro, and automatically creates customer/user

This will create a new company and user in Cloudberry based on your customer's business name, and the user based on the customer's primary contact name and email with a randomly generated password.
The new Account ID and User ID will be saved to the asset under two custom asset fields "Cloudberry_Company_ID" and "Cloudberry_User_ID"
A new Baremetal backup plan is created, that will automatically run at 11pm every night.

1. Create two new custom asset Text Fields in the Syncro Asset type: Cloudberry_Company_ID and Cloudberry_User_ID
2. Add your installer .exe to your Script Files. It MUST be named backup-installer.exe
3. Key in your Syncro subdomain for the $subdomain variable
4. Enter your API username for the $authUserName variable
5. Enter your API password for the $authPass variable

Doesn't parse Storage Limit accounts to grab the ID.  Quickest way I know is to edit a user on msbackups.com, edit the Backup Destination, on the Storage Limit drop-down, right-click the field and choose Inspect (Chrome), drop-down the element that's highlighted, and your Storage Limit IDs should now be visible in the HTML, like this:  <option value="12345">Server 500GB</option>.  12345 would be your cbPackageID

Help Setting Up Your API Credentials

https://mspbackups.com/Admin/Help.aspx?c=Contents%2Fhelp_MBS_API_2.0.html#creds
