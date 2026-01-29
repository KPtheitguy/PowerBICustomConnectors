# ServiceNow Power BI Custom Connector

A custom Power BI connector that enables you to connect to ServiceNow instances and import data from various tables using OAuth 2.0 authentication with PKCE.

## Features

- **OAuth 2.0 with PKCE**: Secure authentication using Authorization Code flow with Proof Key for Code Exchange
- **Dynamic Configuration**: Enter your ServiceNow instance URL, Client ID, and Client Secret at connection time
- **Multiple Tables**: Access common ServiceNow tables including:
  - Incidents
  - Problems
  - Change Requests
  - Users
  - User Groups
  - Configuration Items (CMDB)
  - Tasks
  - Service Requests
  - Requested Items
  - Knowledge Articles
  - Assets
  - Hardware Assets
  - Companies
  - Locations
  - Departments
- **Token Refresh**: Automatic token refresh for long-running sessions

## Prerequisites

### ServiceNow Configuration

1. **Create an OAuth Application in ServiceNow**:
   - Navigate to **System OAuth > Application Registry**
   - Click **New** and select **"Create an OAuth API endpoint for external clients"**
   - Fill in the following:
     - **Name**: Power BI Connector (or any name)
     - **Redirect URL**: `https://oauth.powerbi.com/views/oauthredirect.html`
     - **Active**: Checked
   - Save and note the **Client ID** and **Client Secret**

2. **Configure Auth Scopes**:
   - In your OAuth application, scroll to **Auth Scopes**
   - Click **Insert a new row**
   - Add: `useraccount`
   - Save

3. **User Permissions**:
   - Ensure the user connecting has appropriate roles (e.g., `admin`, `itil`) to access the tables you want to query

### Power BI Desktop Configuration

1. **Enable Custom Connectors**:
   - Open Power BI Desktop
   - Go to **File > Options and settings > Options**
   - Select **Security**
   - Under **Data Extensions**, select **"(Not Recommended) Allow any extension to load without validation or warning"**
   - Click **OK** and restart Power BI Desktop

## Installation

1. Download the `ServiceNowConnector.mez` file
2. Copy it to: `Documents\Power BI Desktop\Custom Connectors\`
   - Create the folder if it doesn't exist
3. Restart Power BI Desktop

## Usage

1. Open Power BI Desktop
2. Click **Get Data**
3. Search for **"ServiceNow"** or find it under **Other**
4. Click **Connect**
5. Enter your connection details:
   - **instance_url**: Your ServiceNow instance URL (e.g., `https://yourcompany.service-now.com`)
   - **client_id**: The Client ID from your OAuth application
   - **client_secret**: The Client Secret from your OAuth application
6. Click **OK**
7. Click **Sign in** to authenticate
8. A browser window will open — log in with your ServiceNow credentials
9. Click **Allow** to grant permissions
10. Once authenticated, select the tables you want to import
11. Click **Load** or **Transform Data**

## Building from Source

### Requirements

- Visual Studio Code with Power Query SDK extension (Windows only)
- Or manually create the `.mez` file

### Manual Build

1. Save the `ServiceNowConnector.pq` file
2. Create a ZIP file containing:
   - `ServiceNowConnector.pq`
   - `resources/` folder with icon files (optional)
3. Rename the `.zip` to `.mez`

## File Structure

```
ServiceNowConnector/
├── ServiceNowConnector.pq      # Main connector code
├── ServiceNowConnector.mez     # Compiled connector (ZIP renamed)
├── README.md                   # This file
└── resources/                  # Icon files (optional)
    ├── ServiceNow16.png
    ├── ServiceNow20.png
    ├── ServiceNow24.png
    ├── ServiceNow32.png
    ├── ServiceNow40.png
    ├── ServiceNow48.png
    └── ServiceNow64.png
```

## Troubleshooting

### "Missing redirect URL in application registration"
- Ensure the Redirect URL in ServiceNow exactly matches: `https://oauth.powerbi.com/views/oauthredirect.html`

### "Missing code_challenge parameter"
- Your ServiceNow instance requires PKCE. This connector supports PKCE by default.

### "Access to the resource is forbidden"
- The authenticated user doesn't have permission to access the requested table
- Add appropriate roles (e.g., `admin`, `itil`) to the user in ServiceNow

### "Authorization wasn't specified"
- Clear data source settings: **File > Options > Data source settings > Delete**
- Restart Power BI Desktop and try again

### Connector not appearing in Get Data
- Verify the `.mez` file is in the correct folder
- Check that custom extensions are enabled in Security settings
- Restart Power BI Desktop

## Security Considerations

- Client secrets are stored securely by Power BI
- OAuth tokens are managed by Power BI's credential system
- PKCE provides additional security for the authorization code flow
- Consider using a dedicated service account for Power BI connections

## Limitations

- Maximum 10,000 records per table (configurable in code)
- Predefined list of common tables (can be extended in code)
- Requires PKCE-enabled OAuth application in ServiceNow

## Extending the Connector

### Adding More Tables

Edit the `tables` list in `ServiceNowConnector.Contents`:

```powerquery-m
tables = {
    [name = "incident", label = "Incidents"],
    [name = "your_custom_table", label = "Your Custom Table"],
    // Add more tables here
},
```

### Changing Record Limit

Edit the `sysparm_limit` parameter in `FetchTableData`:

```powerquery-m
url = instance_url & "/api/now/table/" & tableName & "?sysparm_limit=50000",
```

## License

MIT License

## Support

For issues related to:
- **This connector**: Open an issue in the repository
- **ServiceNow API**: Consult [ServiceNow Documentation](https://docs.servicenow.com/)
- **Power BI**: Consult [Power BI Documentation](https://docs.microsoft.com/power-bi/)

## Changelog

### v1.0.0
- Initial release
- OAuth 2.0 with PKCE support
- Support for 15 common ServiceNow tables
- Dynamic instance URL, Client ID, and Client Secret input