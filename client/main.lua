local CreatedBlip = {}
local CreatedNpc = {}
local MyidOpen = false
local documentMainMenu

local function debugPrint(...)
    if Config.devMode then
        print(...)
    end
end

Citizen.CreateThread(function()
    local DocumentMenuPrompt = BccUtils.Prompts:SetupPromptGroup()
    local documentprompt = DocumentMenuPrompt:RegisterPrompt(_U('PromptName'), 0x760A9C6F, 1, 1, true, 'hold',
        { timedeventhash = 'MEDIUM_TIMED_EVENT' })

    if Config.DocumentBlips then
        for _, v in pairs(Config.DocumentLocations) do
            local DocumentBlip = BccUtils.Blips:SetBlip(_U('BlipName'), 'blip_job_board', 3.2, v.coords.x, v.coords.y,
                v.coords.z)
            CreatedBlip[#CreatedBlip + 1] = DocumentBlip
        end
    end

    if Config.DocumentNPC then
        for _, v in pairs(Config.DocumentLocations) do
            local documentped = BccUtils.Ped:Create('MP_POST_RELAY_MALES_01', v.coords.x, v.coords.y, v.coords.z - 1, 0,
                'world', false)
            CreatedNpc[#CreatedNpc + 1] = documentped
            documentped:Freeze()
            documentped:SetHeading(v.NpcHeading)
            documentped:Invincible()
        end
    end

    while true do
        Wait(1)
        local playerCoords = GetEntityCoords(PlayerPedId())
        for _, v in pairs(Config.DocumentLocations) do
            local dist = #(playerCoords - v.coords)
            if dist < 2 then
                DocumentMenuPrompt:ShowGroup(_U('Licenses'))
                if documentprompt:HasCompleted() then
                    OpenMenu()
                end
            end
        end
    end
end)

function openMainMenu()
    if documentMainMenu then
        documentMainMenu:RouteTo()
    else
        debugPrint("Error: documentMainMenu is not initialized.")
    end
end

function OpenMenu()
    documentMainMenu = ISEEDocumentsMainMenu:RegisterPage("Main:Page")
    documentMainMenu:RegisterElement('header', { value = _U('Licenses'), slot = 'header', style = {} })
    documentMainMenu:RegisterElement('line', { slot = "header", style = {} })

    for docType, settings in pairs(Config.DocumentTypes) do
        documentMainMenu:RegisterElement('button', { label = settings.displayName, style = {} }, function()
            OpenDocumentSubMenu(docType)
        end)
    end

    documentMainMenu:RegisterElement('bottomline', { value = _U('Licenses'), slot = 'footer', style = {} })
    ISEEDocumentsMainMenu:Open({ startupPage = documentMainMenu })
end

function OpenDocumentSubMenu(docType)
    local documentSubMenu = ISEEDocumentsMainMenu:RegisterPage("submenu:" .. docType)

    documentSubMenu:RegisterElement('header',
        { value = Config.DocumentTypes[docType].displayName, slot = 'header', style = {} })
    documentSubMenu:RegisterElement('button',
        { label = _U('RegisterDoc') .. " - $" .. Config.DocumentTypes[docType].price, style = {} }, function()
        TriggerEvent('isee-documents:client:createDocument', docType)
    end)

    if docType == 'idcard' then
        documentSubMenu:RegisterElement('button',
            { label = _U('ChangePicture') .. " - $" .. Config.DocumentTypes[docType].changePhotoPrice, style = {} },
            function()
                ChangeDocumentPhoto(docType)
            end)
    end

    documentSubMenu:RegisterElement('button',
        { label = _U('DocumentLost') .. " - $" .. Config.DocumentTypes[docType].reissuePrice, style = {} }, function()
        TriggerEvent('isee-documents:client:reissueDocument', docType)
    end)

    if docType ~= 'idcard' then
        local docConfig = Config.DocumentTypes[docType]
        documentSubMenu:RegisterElement('button',
            { label = _U('ExtendExpiry') .. " - $" .. docConfig.extendPrice, style = {} }, function()
            AddExpiryDate(docType)
        end)
    end

    documentSubMenu:RegisterElement('button', { label = _U('BackButton'), style = {} }, function()
        openMainMenu()
    end)

    documentSubMenu:RegisterElement('bottomline', { value = _U('Licenses'), slot = 'footer', style = {} })
    ISEEDocumentsMainMenu:Open({ startupPage = documentSubMenu })
end

function ChangeDocumentPhoto(docType)
    local ChangePhotoPage = ISEEDocumentsMainMenu:RegisterPage('change:photo')
    local photoLink = nil

    ChangePhotoPage:RegisterElement('header',
        { value = Config.DocumentTypes[docType].displayName, slot = 'header', style = {} })
    ChangePhotoPage:RegisterElement('input',
        { label = _U('InputPhotolink'), placeholder = _U('PastePhotoLink'), persist = false, style = {} }, function(data)
        if data.value and data.value ~= "" then
            photoLink = data.value
        else
            debugPrint("Invalid photo URL.")
        end
    end)

    ChangePhotoPage:RegisterElement('button', { label = _U('Submit'), style = { ['border-radius'] = '6px' } }, function()
        if docType and photoLink then
            TriggerServerEvent('isee-documents:server:changeDocumentPhoto', docType, photoLink)
            OpenDocumentSubMenu(docType)
        else
            debugPrint("Error: Missing document type or photo URL.")
        end
    end)

    ChangePhotoPage:RegisterElement('button', { label = _U('BackButton'), style = {} }, function()
        OpenDocumentSubMenu(docType)
    end)

    ISEEDocumentsMainMenu:Open({ startupPage = ChangePhotoPage })
end

function AddExpiryDate(docType)
    local inputPage = ISEEDocumentsMainMenu:RegisterPage("input:expiry")
    local daysToAdd = nil

    inputPage:RegisterElement('header',
        { value = Config.DocumentTypes[docType].displayName, slot = 'header', style = {} })
    inputPage:RegisterElement('input',
        { label = _U('EnterExpiryDays'), placeholder = _U('NumberOfDays'), inputType = 'number', slot = 'content', style = {} },
        function(data)
            if tonumber(data.value) and tonumber(data.value) > 0 then
                daysToAdd = tonumber(data.value)
            else
                daysToAdd = nil
                debugPrint("Invalid input for days.")
            end
        end)

    inputPage:RegisterElement('button', { label = _U('Confirm'), style = { ['border-radius'] = '6px' } }, function()
        if daysToAdd then
            TriggerServerEvent('isee-documents:server:updateExpiryDate', docType, daysToAdd)
            OpenDocumentSubMenu(docType)
        else
            debugPrint("Error: Number of days not set or invalid.")
        end
    end)

    inputPage:RegisterElement('button', { label = _U('BackButton'), style = {} }, function()
        OpenDocumentSubMenu(docType)
    end)

    ISEEDocumentsMainMenu:Open({ startupPage = inputPage })
end

function ShowDocument(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
    if not MyidOpen then
        local DocumentPageShow = ISEEDocumentsMainMenu:RegisterPage("show:document")
        DocumentPageShow:RegisterElement('header', { value = Config.DocumentTypes[docType].displayName, slot = 'header' })
        DocumentPageShow:RegisterElement('line', { slot = 'header' })
        DocumentPageShow:RegisterElement("html",
            { slot = 'header', value = [[<img width="200px" height="200px" style="margin: 0 auto;" src="]] ..
            (picture or 'default_picture_url_here') .. [[" />]] })
        DocumentPageShow:RegisterElement("html", {
            value = [[
            <div style="text-align: center; margin-top: 10px;">
                <p><b>]] .. _U('Firstname') .. [[</b> ]] .. (firstname or 'Unknown') .. [[</p>
                <p><b>]] .. _U('Lastname') .. [[</b> ]] .. (lastname or 'Unknown') .. [[</p>
                <p><b>]] .. _U('Nickname') .. [[</b> ]] .. (nickname or 'Unknown') .. [[</p>
                <p><b>]] .. _U('Job') .. [[</b> ]] .. (job or 'Unknown') .. [[</p>
                <p><b>]] .. _U('Age') .. [[</b> ]] .. (age or 'Unknown') .. [[</p>
                <p><b>]] .. _U('Gender') .. [[</b> ]] .. (gender or 'Unknown') .. [[</p>
                <p><b>]] .. _U('CreationDate') .. [[</b> ]] .. (date or 'Unknown') .. [[</p>
                <p><b>]] .. _U('ExpiryDate') .. [[</b> ]] .. (expire_date or 'N/A') .. [[</p>
            </div>
        ]]
        })

        MyidOpen = true
        ISEEDocumentsMainMenu:Open({ startupPage = DocumentPageShow })
    else
        ISEEDocumentsMainMenu:Close()
        MyidOpen = false
    end
end

function OpenDocument(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
    if not MyidOpen then
        local DocumentPageOpen = ISEEDocumentsMainMenu:RegisterPage("open:document")
        DocumentPageOpen:RegisterElement('header', { value = Config.DocumentTypes[docType].displayName, slot = 'header' })
        DocumentPageOpen:RegisterElement('line', { slot = 'header' })
        DocumentPageOpen:RegisterElement("html",
            { slot = 'header', value = [[<img width="200px" height="200px" style="margin: 0 auto;" src="]] ..
            (picture or 'default_picture_url_here') .. [[" />]] })
        DocumentPageOpen:RegisterElement("html", {
            value = [[
            <div style="text-align: center; margin-top: 10px;">
                <p><b>]] .. _U('Firstname') .. [[</b> ]] .. (firstname or 'Unknown') .. [[</p>
                <p><b>]] .. _U('Lastname') .. [[</b> ]] .. (lastname or 'Unknown') .. [[</p>
                <p><b>]] .. _U('Nickname') .. [[</b> ]] .. (nickname or 'Unknown') .. [[</p>
                <p><b>]] .. _U('Job') .. [[</b> ]] .. (job or 'Unknown') .. [[</p>
                <p><b>]] .. _U('Age') .. [[</b> ]] .. (age or 'Unknown') .. [[</p>
                <p><b>]] .. _U('Gender') .. [[</b> ]] .. (gender or 'Unknown') .. [[</p>
                <p><b>]] .. _U('CreationDate') .. [[</b> ]] .. (date or 'Unknown') .. [[</p>
                <p><b>]] .. _U('ExpiryDate') .. [[</b> ]] .. (expire_date or 'N/A') .. [[</p>
            </div>
        ]]
        })

        DocumentPageOpen:RegisterElement('button', { label = _U('ShowDocument'), style = { ['border-radius'] = '6px' } },
            function()
                OpenShowToPlayerMenu(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
            end)
        DocumentPageOpen:RegisterElement('button',
            { label = _U('RevokeDocument'), style = { ['border-radius'] = '6px' } }, function()
            if docType and docType ~= '' then
                TriggerServerEvent('isee-documents:server:revokeMyDocument', docType)
                Wait(500) -- Small delay to ensure synchronization
                ISEEDocumentsMainMenu:Close()
            else
                debugPrint("Error: docType is nil or empty")
            end
        end)
        DocumentPageOpen:RegisterElement('button', { label = _U('PutBack'), style = { ['border-radius'] = '6px' } },
            function()
                ISEEDocumentsMainMenu:Close()
            end)

        MyidOpen = true
        ISEEDocumentsMainMenu:Open({ startupPage = DocumentPageOpen })
    else
        --ISEEDocumentsMainMenu:Close()
        MyidOpen = false
    end
end

function OpenShowToPlayerMenu(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
    local players = GetNearbyPlayers()
    local playerMenu = ISEEDocumentsMainMenu:RegisterPage("playerMenu")

    playerMenu:RegisterElement('header', { value = _U('ChoosePlayer'), slot = 'header' })

    if #players > 0 then
        for _, player in ipairs(players) do
            debugPrint("Nearby Player:", player.id, GetPlayerName(GetPlayerFromServerId(player.id)))
            playerMenu:RegisterElement('button', { label = GetPlayerName(GetPlayerFromServerId(player.id)), style = {} },
                function()
                    TriggerServerEvent('isee-documents:server:showDocumentToPlayer', player.id, docType, firstname,
                        lastname, nickname, job, age, gender, date, picture, expire_date)
                    Wait(500) -- Small delay to ensure synchronization
                    VORPcore.NotifyObjective(
                    GetPlayerName(GetPlayerFromServerId(player.id)) .. " - Verifica documentul dvs", 4000)
                end)
        end
    else
        playerMenu:RegisterElement('text',
            { value = _U('NoNearbyPlayer'), style = { color = 'red', ['text-align'] = 'center', ['margin-top'] = '10px' } })
    end

    playerMenu:RegisterElement('button', { label = _U('BackButton'), style = {} }, function()
        OpenDocument(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
    end)

    ISEEDocumentsMainMenu:Open({ startupPage = playerMenu })
end

function GetNearbyPlayers()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local nearbyPlayers = {}

    for _, player in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(player)
        if targetPed ~= playerPed then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(playerCoords - targetCoords)
            if distance < 3.0 then
                table.insert(nearbyPlayers, { id = GetPlayerServerId(player), distance = distance })
                debugPrint("Found nearby player:", GetPlayerServerId(player))
            end
        end
    end

    return nearbyPlayers
end

RegisterNetEvent('isee-documents:opensubmenu')
AddEventHandler('isee-documents:opensubmenu', function(docType)
    OpenDocumentSubMenu(docType)
end)

RegisterNetEvent('isee-documents:client:opendocument')
AddEventHandler('isee-documents:client:opendocument',
    function(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
        OpenDocument(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
    end)

RegisterNetEvent('isee-documents:client:addexpiry')
AddEventHandler('isee-documents:client:addexpiry', function(docType)
    AddExpiryDate(docType)
end)

RegisterNetEvent('isee-documents:client:showdocument')
AddEventHandler('isee-documents:client:showdocument',
    function(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
        ShowDocument(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
    end)

RegisterNetEvent('isee-documents:client:noDocument')
AddEventHandler('isee-documents:client:noDocument', function()
    debugPrint("No document found for this type.")
end)

RegisterNetEvent('isee-documents:client:createDocument')
AddEventHandler('isee-documents:client:createDocument', function(docType)
    if docType then
        TriggerServerEvent('isee-documents:server:createDocument', docType)
    else
        debugPrint("Error: docType is missing.")
    end
end)

RegisterNetEvent('isee-documents:client:reissueDocument')
AddEventHandler('isee-documents:client:reissueDocument', function(docType)
    if docType then
        TriggerServerEvent('isee-documents:server:reissueDocument', docType)
    else
        debugPrint("Error: docType is missing.")
    end
end)

RegisterNetEvent('isee-documents:client:revokeDocument')
AddEventHandler('isee-documents:client:revokeDocument', function(docType)
    if docType then
        TriggerServerEvent('isee-documents:server:revokeDocument', docType)
    else
        debugPrint("Error: docType is missing.")
    end
end)

RegisterNetEvent('isee-documents:client:changephoto')
AddEventHandler('isee-documents:client:changephoto', function(docType)
    ChangeDocumentPhoto(docType)
end)

RegisterNetEvent('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for _, npcs in ipairs(CreatedNpc) do
            npcs:Remove()
        end
        for _, blips in ipairs(CreatedBlip) do
            blips:Remove()
        end
    end
end)
