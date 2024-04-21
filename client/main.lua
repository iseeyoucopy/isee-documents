BccUtils = exports['bcc-utils'].initiate()
FeatherMenu =  exports['feather-menu'].initiate()

local CreatedBlip = {}
local CreatedNpc = {}
local MyidOpen = false
local inmenu = false
local documentMainMenu

ISEEDocumentsMainMenu = FeatherMenu:RegisterMenu('document:mainmenu', {
    top = '40%',
    left = '20%',
    ['720width'] = '500px',
    ['1080width'] = '600px',
    ['2kwidth'] = '700px',
    ['4kwidth'] = '900px',
    style = {},
    contentslot = {
        style = {
            ['height'] = '300px',
            ['min-height'] = '300px'
        }
    },
    draggable = true
})
AddEventHandler('isee-documents:MenuClose', function()
    Citizen.CreateThread(function()   -- Ensure this runs in a separate thread
        if not inmenu then return end -- Exit if not in a menu
        while inmenu do
            Wait(5)
            if IsControlJustReleased(0, 0x156F7119) then -- B (space) to exit
                if ISEEDocumentsMainMenu and ISEEDocumentsMainMenu.isOpen then
                    ISEEDocumentsMainMenu:Close()
                    inmenu = false
                end
            end
        end
    end)
end)

Citizen.CreateThread(function()
    local DocumentMenuPrompt = BccUtils.Prompts:SetupPromptGroup()
    local documentprompt = DocumentMenuPrompt:RegisterPrompt(_U('PromptName'), 0x760A9C6F, 1, 1, true, 'hold',
        { timedeventhash = 'MEDIUM_TIMED_EVENT' })
    if Config.DocumentBlips then
        for h, v in pairs(Config.DocumentLocations) do
            local DocumentBlip = BccUtils.Blips:SetBlip(_U('BlipName'), 'blip_job_board', 3.2, v.coords.x, v.coords.y,
                v.coords.z)
            CreatedBlip[#CreatedBlip + 1] = DocumentBlip
        end
    end
    if Config.DocumentNPC then
        for h, v in pairs(Config.DocumentLocations) do
            local documentped = BccUtils.Ped:Create('MP_POST_RELAY_MALES_01', v.coords.x, v.coords.y, v.coords.z - 1, 0, 'world', false)
            CreatedNpc[#CreatedNpc + 1] = documentped
            documentped:Freeze()
            documentped:SetHeading(v.NpcHeading)
            documentped:Invincible()
        end
    end
    while true do
        Wait(1)
        for h, v in pairs(Config.DocumentLocations) do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local dist = #(playerCoords - v.coords)
            if dist < 2 then
                DocumentMenuPrompt:ShowGroup(_U('Licenses'))
                if documentprompt:HasCompleted() then
                    TriggerEvent('isee:documents:openmenu')
                end
            end
        end
    end
end)

AddEventHandler('isee:documents:openmenu', function()
    TriggerEvent('isee-documents:MenuClose')
    ISEEDocumentsMainMenu:Close()
    -- Register the main page for documents
    documentMainMenu = ISEEDocumentsMainMenu:RegisterPage("isee-documents:MainPage")
    documentMainMenu:RegisterElement('header', {
        value = _U('Licenses'), -- Registration
        slot = 'header',
        style = {}
    })
    documentMainMenu:RegisterElement('line', {
        slot = "header",
        style = {}
    })
    -- Iterate over each document type and create elements for them
    for docType, settings in pairs(Config.DocumentTypes) do
        documentMainMenu:RegisterElement('button', {
            label = settings.displayName,
            style = {}
        }, function()
            TriggerEvent('isee:documents:opensubmenu', docType)
        end)
    end

    -- Footer elements outside the loop
    documentMainMenu:RegisterElement('bottomline', {
        value = _U('Licenses'),
        slot = 'footer',
        style = {}
    })

    -- Open the menu with the configured main page
    ISEEDocumentsMainMenu:Open({
        startupPage = documentMainMenu
    })
end)

-- Function to open the main menu
function openMainMenu()
    if documentMainMenu then
        documentMainMenu:RouteTo()
    else
        print("Error: documentMainMenu is not initialized.")
    end
end

AddEventHandler('isee:documents:opensubmenu', function(docType, daysToAdd)
    local documentSubMenu = ISEEDocumentsMainMenu:RegisterPage("isee-documents-submenu-" .. docType)

    -- Add a header to the submenu showing the document type
    documentSubMenu:RegisterElement('header', {
        value = Config.DocumentTypes[docType].displayName, -- Dynamically use the display name from settings
        slot = 'header',
        style = {}
    })

    -- Button for buying the license, available for all document types
    documentSubMenu:RegisterElement('button', {
        label = _U('RegisterDoc') .. " - $" .. Config.DocumentTypes[docType].price,
        style = {},
    }, function()
        TriggerEvent('isee-documents:client:createDocument', docType)
    end)

    -- Conditional button for changing the picture, only for ID Cards
    if docType == 'idcard' then
        documentSubMenu:RegisterElement('button', {
            label = _U('ChangePicture') .. " - $" .. Config.DocumentTypes[docType].changePhotoPrice,
            style = {},
        }, function()
            -- This gets triggered whenever the button is clicked
            TriggerEvent('isee-documents:client:changephoto', docType)
        end)
    end

    -- Button for reissuing the document, available for all document types
    documentSubMenu:RegisterElement('button', {
        label = _U('DocumentLost') .. " - $" .. Config.DocumentTypes[docType].reissuePrice,
        style = {},
    }, function()
        TriggerEvent('isee-documents:client:reissueDocument', docType)
    end)

    if docType ~= 'idcard' and Config.DocumentTypes[docType] then
        local docConfig = Config.DocumentTypes[docType]
        documentSubMenu:RegisterElement('button', {
            label = _U('ExtendExpiry') .. " - $" .. docConfig.reissuePrice,
            style = {},
        }, function()
            -- Trigger an event with docType to specify the number of extra days
            TriggerEvent('isee-documents:client:addexpiry', docType)
        end)
    else
        print("Attempted to extend expiry for unsupported or undefined docType:", docType)
    end

    -- Register a back button on the submenu that routes to the main menu
    documentSubMenu:RegisterElement('button', {
        label = _U('BackButton'),
        style = {}
    }, function()
        openMainMenu() -- This function will call RouteTo on the main menu
    end)

    -- Assuming you have some mechanism to open the submenu
    function openSubMenu()
        if documentSubMenu then
            documentSubMenu:RouteTo()
        else
            print("Error: documentSubMenu is not initialized.")
        end
    end

    -- Footer elements outside the loop
    documentSubMenu:RegisterElement('bottomline', {
        value = _U('Licenses'),
        slot = 'footer',
        style = {}
    })

    -- Open the submenu with the configured main page
    ISEEDocumentsMainMenu:Open({
        startupPage = documentSubMenu
    })
end)

RegisterNetEvent('isee-documents:client:changephoto')
AddEventHandler('isee-documents:client:changephoto', function(docType)
    local ChangePhotoPage = ISEEDocumentsMainMenu:RegisterPage('document_change_photo_page')
    local photoLink = nil -- Variable to store the photo URL

    ChangePhotoPage:RegisterElement('header', {
        value = Config.DocumentTypes[docType].displayName, -- Dynamically use the display name from settings
        slot = 'header',
        style = {}
    })

    ChangePhotoPage:RegisterElement('input', {
        label = _U('InputPhotolink'),
        placeholder = _U('PastePhotoLink'),
        persist = false,
        style = {}
    }, function(data)
        if data.value and data.value ~= "" then
            photoLink = data.value -- Store the entered photo URL
            --print("Photo URL set to:", photoLink)  -- Debug print to confirm it's set
        else
            --print("No input received or invalid input.")
        end
    end)

    ChangePhotoPage:RegisterElement('button', {
        label = _U('Submit'),
        style = {
            ['border-radius'] = '6px',
        },
    }, function()
        if docType and photoLink then
            TriggerServerEvent('isee-documents:server:changeDocumentPhoto', docType, photoLink)
            openSubMenu()
        else
            print("Error: Missing document type or photo URL.")
        end
    end)

    -- Register a back button on the submenu that routes to the previous menu
    ChangePhotoPage:RegisterElement('button', {
        label = _U('BackButton'),
        style = {}
    }, function()
        openSubMenu() -- This function will call RouteTo on previous menu
    end)

    ISEEDocumentsMainMenu:Open({
        startupPage = ChangePhotoPage
    })
end)

RegisterNetEvent('isee-documents:client:addexpiry')
AddEventHandler('isee-documents:client:addexpiry', function(docType)
    local inputPage = ISEEDocumentsMainMenu:RegisterPage("isee-documents-input-expiry")
    local daysToAdd = nil -- Variable to store the number of days

    inputPage:RegisterElement('header', {
        value = Config.DocumentTypes[docType].displayName, -- Dynamically use the display name from settings
        slot = 'header',
        style = {}
    })

    inputPage:RegisterElement('input', {
        label = _U('EnterExpiryDays'),
        placeholder = _U('NumberOfDays'),
        inputType = 'number',
        slot = 'content',
        style = {
            ['border-radius'] = '6px',
            ['background-color'] = '#E8E8E8',
            ['color'] = 'black'
        },
    }, function(data)
        if tonumber(data.value) and tonumber(data.value) > 0 then
            daysToAdd = data.value
        else
            daysToAdd = nil
            print("Invalid input for days.")
        end
    end)

    inputPage:RegisterElement('button', {
        label = _U('Confirm'),
        style = {
            ['border-radius'] = '6px',
        },
    }, function()
        if daysToAdd then
            TriggerServerEvent('isee-documents:server:updateExpiryDate', docType, daysToAdd)
            ISEEDocumentsMainMenu:Close()
        else
            print("Error: Number of days not set or invalid.")
        end
    end)

    -- Register a back button on the submenu that routes to the previous menu
    inputPage:RegisterElement('button', {
        label = _U('BackButton'),
        style = {}
    }, function()
        openSubMenu() -- This function will call RouteTo on previous menu
    end)

    ISEEDocumentsMainMenu:Open({
        startupPage = inputPage
    })
end)

RegisterNetEvent('isee-documents:client:createDocument')
AddEventHandler('isee-documents:client:createDocument', function(docType)
    if docType then
        --print("Triggering document create for type:", docType)
        TriggerServerEvent('isee-documents:server:createDocument', docType)
    else
        print("Error: docType is missing.")
    end
end)

RegisterNetEvent('isee-documents:client:reissueDocument')
AddEventHandler('isee-documents:client:reissueDocument', function(docType)
    if docType then
        --print("Triggering document reissue for type:", docType)
        TriggerServerEvent('isee-documents:server:reissueDocument', docType)
    else
        print("Error: docType is missing.")
    end
end)

RegisterNetEvent('isee-documents:client:revokeDocument')
AddEventHandler('isee-documents:client:revokeDocument', function(docType)
    if docType then
        --print("Triggering document reissue for type:", docType)
        TriggerServerEvent('isee-documents:server:revokeDocument', docType)
    else
        print("Error: docType is missing.")
    end
end)

RegisterNetEvent('isee-documents:client:showdocument')
AddEventHandler('isee-documents:client:showdocument',
    function(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
        -- Only open a new ID document page if it's not already open
        if not MyidOpen then
            -- Create or reset the page for viewing ID
            local DocumentPage = ISEEDocumentsMainMenu:RegisterPage("isee-documents-open-ID")
            -- Register generic elements that do not change
            DocumentPage:RegisterElement('header', {
                value = Config.DocumentTypes[docType].displayName,
                slot = 'header'
            })
            DocumentPage:RegisterElement('line', {
                slot = 'header'
            })
            DocumentPage:RegisterElement("html", {
                slot = 'header',
                value = [[<img width="200px" height="200px" style="margin: 0 auto;" src="]] ..
                    (picture or 'default_picture_url_here') .. [[" />]]
            })

            -- Register dynamic text elements
            local elements = {
                { label = 'DocType',      value = docType },
                { label = 'Firstname',    value = firstname },
                { label = 'Lastname',     value = lastname },
                { label = 'Nickname',     value = nickname },
                { label = 'Job',          value = job },
                { label = 'Age',          value = age },
                { label = 'Gender',       value = gender },
                { label = 'CreationDate', value = date },
                { label = 'ExpiryDate',   value = expire_date or 'N/A' } -- Include expiry date or show 'N/A' if not available
            }

            for _, elem in ipairs(elements) do
                DocumentPage:RegisterElement('subheader', {
                    value = _U(elem.label) .. (elem.value or 'Unknown') .. '.',
                    style = {}
                })
            end

            -- Flag the document as open and display it
            MyidOpen = true
            ISEEDocumentsMainMenu:Open({ startupPage = DocumentPage })
        else
            -- Simply close the document if it's already open (toggle functionality)
            ISEEDocumentsMainMenu:Close()
            MyidOpen = false
        end
    end)

RegisterNetEvent('isee-documents:client:noDocument')
AddEventHandler('isee-documents:client:noDocument', function()
    print("No document found for this type.")
end)

RegisterNetEvent('isee-documents:client:opendocument')
AddEventHandler('isee-documents:client:opendocument',
    function(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
        -- Only open a new ID document page if it's not already open
        if not MyidOpen then
            -- Create or reset the page for viewing ID
            local DocumentPage = ISEEDocumentsMainMenu:RegisterPage("isee-documents-open-ID")
            -- Ensure the page registration and element addition is successful
            if DocumentPage then
                print("Document page created successfully.")
            else
                print("Failed to create document page.")
            end
            -- Register generic elements that do not change
            DocumentPage:RegisterElement('header', {
                value = Config.DocumentTypes[docType].displayName,
                slot = 'header'
            })
            DocumentPage:RegisterElement('line', { slot = 'header' })
            DocumentPage:RegisterElement("html", {
                slot = 'header',
                value = [[<img width="200px" height="200px" style="margin: 0 auto;" src="]] ..
                    (picture or 'default_picture_url_here') .. [[" />]]
            })

            -- Register dynamic text elements
            local elements = {
                { label = 'Firstname',    value = firstname },
                { label = 'Lastname',     value = lastname },
                { label = 'Nickname',     value = nickname },
                { label = 'Job',          value = job },
                { label = 'Age',          value = age },
                { label = 'Gender',       value = gender },
                { label = 'CreationDate', value = date },
                { label = 'ExpiryDate',   value = expire_date or 'N/A' } -- Include expiry date or show 'N/A' if not available
            }

            for _, elem in ipairs(elements) do
                DocumentPage:RegisterElement('textdisplay', {
                    value = _U(elem.label) .. (elem.value or 'Unknown'),
                    style = {}
                })
            end

            -- Register actions
            DocumentPage:RegisterElement('button', {
                label = _U('ShowDocument') .. Config.DocumentTypes[docType].displayName,
                style = { ['border-radius'] = '6px' },
            }, function()
                TriggerServerEvent('isee-documents:server:showDocumentClosestPlayer', docType)
            end)
            DocumentPage:RegisterElement('button', {
                label = _U('PutBack') .. Config.DocumentTypes[docType].displayName,
                style = { ['border-radius'] = '6px' },
            }, function()
                ISEEDocumentsMainMenu:Close({
                })
            end)

            -- Flag the document as open and display it
            MyidOpen = true
            ISEEDocumentsMainMenu:Open({ startupPage = DocumentPage })
        else
            -- Simply close the document if it's already open (toggle functionality)
            ISEEDocumentsMainMenu:Close()
            MyidOpen = false
        end
    end)

---- CleanUp on Resource Restart
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
