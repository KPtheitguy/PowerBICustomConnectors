section ServiceNowConnector;

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

// Generate random string for PKCE
GenerateCodeVerifier = () =>
    let
        chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
        randomList = List.Generate(
            () => [i = 0, c = Text.At(chars, Number.RoundDown(Number.RandomBetween(0, 63)))],
            each [i] < 43,
            each [i = [i] + 1, c = Text.At(chars, Number.RoundDown(Number.RandomBetween(0, 63)))],
            each [c]
        ),
        verifier = Text.Combine(randomList)
    in
        verifier;

// Generate SHA256 hash for code challenge
GenerateCodeChallenge = (verifier as text) =>
    let
        hash = Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(verifier, TextEncoding.Ascii)),
        base64 = Binary.ToText(hash, BinaryEncoding.Base64),
        base64url = Text.Replace(Text.Replace(Text.TrimEnd(base64, "="), "+", "-"), "/", "_")
    in
        base64url;

// Main entry point
[DataSource.Kind="ServiceNowConnector", Publish="ServiceNowConnector.Publish"]
shared ServiceNowConnector.Contents = (
    instance_url as text,
    client_id as text,
    client_secret as text
) as table =>
    let
        cred = Extension.CurrentCredential(),
        token = cred[access_token],
        
        // Common ServiceNow tables
        tables = {
            [name = "incident", label = "Incidents"],
            [name = "problem", label = "Problems"],
            [name = "change_request", label = "Change Requests"],
            [name = "sys_user", label = "Users"],
            [name = "sys_user_group", label = "User Groups"],
            [name = "cmdb_ci", label = "Configuration Items"],
            [name = "task", label = "Tasks"],
            [name = "sc_request", label = "Service Requests"],
            [name = "sc_req_item", label = "Requested Items"],
            [name = "kb_knowledge", label = "Knowledge Articles"],
            [name = "ast_asset", label = "Assets"],
            [name = "alm_hardware", label = "Hardware Assets"],
            [name = "core_company", label = "Companies"],
            [name = "cmn_location", label = "Locations"],
            [name = "cmn_department", label = "Departments"]
        },
        
        tableList = Table.FromRecords(tables),
        withData = Table.AddColumn(tableList, "Data", each FetchTableData(instance_url, token, [name]), type table),
        navTable = Table.ToNavigationTable(withData, {"name"}, "label", "Data", "name", "label", false)
    in
        navTable;

// Fetch data from a specific ServiceNow table
FetchTableData = (instance_url as text, token as text, tableName as text) as table =>
    let
        url = instance_url & "/api/now/table/" & tableName & "?sysparm_limit=10000",
        response = Web.Contents(url, [
            Headers = [
                Authorization = "Bearer " & token,
                Accept = "application/json"
            ]
        ]),
        json = Json.Document(response),
        result = json[result],
        output = if List.Count(result) = 0 
                 then Table.FromRows({}, {}) 
                 else 
                    let
                        table = Table.FromList(result, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
                        expanded = Table.ExpandRecordColumn(table, "Column1", Record.FieldNames(result{0}))
                    in
                        expanded
    in
        output;

// Navigation table helper function
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as logical
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

// Parse connection parameters from data source path
GetParamsFromPath = (path as text) as record =>
    Json.Document(path);

// Data source definition
ServiceNowConnector = [
    TestConnection = (dataSourcePath) => 
        let 
            params = GetParamsFromPath(dataSourcePath)
        in
            {"ServiceNowConnector.Contents", params[instance_url], params[client_id], params[client_secret]},
    
    Authentication = [
        OAuth = [
            StartLogin = (dataSourcePath, state, display) =>
                let
                    params = GetParamsFromPath(dataSourcePath),
                    code_verifier = GenerateCodeVerifier(),
                    code_challenge = GenerateCodeChallenge(code_verifier),
                    authorizeUrl = params[instance_url] & "/oauth_auth.do"
                        & "?response_type=code"
                        & "&client_id=" & params[client_id]
                        & "&redirect_uri=" & Uri.EscapeDataString(redirect_uri)
                        & "&state=" & Uri.EscapeDataString(state)
                        & "&code_challenge=" & code_challenge
                        & "&code_challenge_method=S256"
                in
                    [
                        LoginUri = authorizeUrl,
                        CallbackUri = redirect_uri,
                        WindowHeight = 720,
                        WindowWidth = 1024,
                        Context = dataSourcePath & "|" & code_verifier
                    ],
            
            FinishLogin = (context, callbackUri, state) =>
                let
                    contextParts = Text.Split(context, "|"),
                    paramsJson = contextParts{0},
                    code_verifier = contextParts{1},
                    params = GetParamsFromPath(paramsJson),
                    
                    parts = Uri.Parts(callbackUri)[Query],
                    code = parts[code],
                    tokenUrl = params[instance_url] & "/oauth_token.do",
                    
                    tokenBody = "grant_type=authorization_code"
                        & "&code=" & Uri.EscapeDataString(code)
                        & "&client_id=" & Uri.EscapeDataString(params[client_id])
                        & "&client_secret=" & Uri.EscapeDataString(params[client_secret])
                        & "&redirect_uri=" & Uri.EscapeDataString(redirect_uri)
                        & "&code_verifier=" & code_verifier,
                    
                    tokenResponse = Web.Contents(tokenUrl, [
                        Content = Text.ToBinary(tokenBody),
                        Headers = [#"Content-Type" = "application/x-www-form-urlencoded"],
                        ManualStatusHandling = {400, 401, 500}
                    ]),
                    
                    responseText = Text.FromBinary(tokenResponse),
                    tokenJson = try Json.Document(tokenResponse) 
                                otherwise error Error.Record("Token Error", "Response: " & responseText)
                in
                    [
                        access_token = if Record.HasFields(tokenJson, "access_token") 
                                       then tokenJson[access_token] 
                                       else error Error.Record("No Token", "Response: " & responseText),
                        refresh_token = if Record.HasFields(tokenJson, "refresh_token") 
                                        then tokenJson[refresh_token] 
                                        else null
                    ],
            
            Refresh = (dataSourcePath, refresh_token) =>
                let
                    paramsJson = if Text.Contains(dataSourcePath, "|") 
                                 then Text.Split(dataSourcePath, "|"){0} 
                                 else dataSourcePath,
                    params = GetParamsFromPath(paramsJson),
                    tokenUrl = params[instance_url] & "/oauth_token.do",
                    tokenResponse = Web.Contents(tokenUrl, [
                        Content = Text.ToBinary(
                            "grant_type=refresh_token"
                            & "&refresh_token=" & Uri.EscapeDataString(refresh_token)
                            & "&client_id=" & Uri.EscapeDataString(params[client_id])
                            & "&client_secret=" & Uri.EscapeDataString(params[client_secret])
                        ),
                        Headers = [#"Content-Type" = "application/x-www-form-urlencoded"],
                        ManualStatusHandling = {400, 401, 500}
                    ]),
                    tokenJson = Json.Document(tokenResponse)
                in
                    [
                        access_token = tokenJson[access_token],
                        refresh_token = if Record.HasFields(tokenJson, "refresh_token") 
                                        then tokenJson[refresh_token] 
                                        else refresh_token
                    ]
        ]
    ],
    Label = "ServiceNow"
];

// Publish information for Power BI UI
ServiceNowConnector.Publish = [
    Beta = true,
    Category = "Online Services",
    ButtonText = {"ServiceNow", "Connect to ServiceNow"},
    LearnMoreUrl = "https://docs.servicenow.com/",
    SourceImage = ServiceNowConnector.Icons,
    SourceTypeImage = ServiceNowConnector.Icons
];

// Icons for the connector (single logo resized)
ServiceNowConnector.Icons = [
    Icon16 = {Extension.Contents("ServiceNow16.png"), Extension.Contents("ServiceNow20.png"), Extension.Contents("ServiceNow24.png"), Extension.Contents("ServiceNow32.png")},
    Icon32 = {Extension.Contents("ServiceNow32.png"), Extension.Contents("ServiceNow40.png"), Extension.Contents("ServiceNow48.png"), Extension.Contents("ServiceNow64.png")}
];
