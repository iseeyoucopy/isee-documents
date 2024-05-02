FeatherMenu =  exports['feather-menu'].initiate()

BccUtils = exports['bcc-utils'].initiate()


local CreatedBlip = {}
local CreatedNpc = {}
local MyidOpen = false
local documentMainMenu 

local ISEEDocumentsMainMenu = FeatherMenu:RegisterMenu('document:mainmenu', {
    top = '40%',  -- Adjust top position as needed
    right = '20px',  -- Position on the right side with 20px from the edge
    ['720width'] = '500px',
    ['1080width'] = '600px',
    ['2kwidth'] = '700px',
    ['4kwidth'] = '900px',
    style = {
        ['background'] = 'linear-gradient(to bottom right, #514740, #261a0f)',
        ['border'] = '2px solid #d6c7b7',
        ['border-radius'] = '15px',
        ['box-shadow'] = '0px 8px 16px rgba(0, 0, 0, 0.5)',
        ['color'] = '#d6c7b7',
        ['font-family'] = 'Georgia, serif',
        ['font-size'] = '18px',
        ['padding'] = '20px',  -- Add padding around the menu
        ['overflow'] = 'hidden',
        ['z-index'] = '9999',
    },
    contentslot = {
        style = {
            ['background'] = 'none',
            ['border-radius'] = '10px',
            ['overflow-y'] = 'auto',
        }
    },
    draggable = true
})

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
                    OpenMenu()
                end
            end
        end
    end
end)

-- Function to open the main menu
function openMainMenu()
    if documentMainMenu then
        documentMainMenu:RouteTo()
    else
        print("Error: documentMainMenu is not initialized.")
    end
end

function OpenMenu()
    -- Register the main page for documents
    documentMainMenu = ISEEDocumentsMainMenu:RegisterPage("Main:Page")
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
            OpenDocumentSubMenu(docType)
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
end

function OpenDocumentSubMenu(docType)
    local documentSubMenu = ISEEDocumentsMainMenu:RegisterPage("submenu:" .. docType)

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
            ChangeDocumentPhoto(docType)
        end)
    end

    -- Button for reissuing the document, available for all document types
    documentSubMenu:RegisterElement('button', {
        label = _U('DocumentLost') .. " - $" .. Config.DocumentTypes[docType].reissuePrice,
        style = {},
    }, function()
        TriggerEvent('isee-documents:client:reissueDocument', docType)
    end)

    -- Conditional button for extending the expiry date
    if docType ~= 'idcard' and Config.DocumentTypes[docType] then
        local docConfig = Config.DocumentTypes[docType]
        documentSubMenu:RegisterElement('button', {
            label = _U('ExtendExpiry') .. " - $" .. docConfig.reissuePrice,
            style = {},
        }, function()
            AddExpiryDate(docType)
        end)
    end

    -- Register a back button on the submenu that routes to the main menu
    documentSubMenu:RegisterElement('button', {
        label = _U('BackButton'),
        style = {}
    }, function()
        openMainMenu() -- This function will call RouteTo on the main menu
    end)

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
end

-- Function to handle changing photo in documents menu
function ChangeDocumentPhoto(docType)
    local ChangePhotoPage = ISEEDocumentsMainMenu:RegisterPage('change:photo')
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
            OpenDocumentSubMenu(docType)
        else
            print("Error: Missing document type or photo URL.")
        end
    end)

    -- Register a back button on the submenu that routes to the previous menu
    ChangePhotoPage:RegisterElement('button', {
        label = _U('BackButton'),
        style = {}
    }, function()
        OpenDocumentSubMenu(docType) -- This function will call RouteTo on previous menu
    end)

    ISEEDocumentsMainMenu:Open({
        startupPage = ChangePhotoPage
    })
end

-- Function to handle adding expiry date in documents menu
function AddExpiryDate(docType)
    local inputPage = ISEEDocumentsMainMenu:RegisterPage("input:expiry")
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
        style = {},
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
            OpenDocumentSubMenu(docType)
        else
            print("Error: Number of days not set or invalid.")
        end
    end)

    -- Register a back button on the submenu that routes to the previous menu
    inputPage:RegisterElement('button', {
        label = _U('BackButton'),
        style = {}
    }, function()
        OpenDocumentSubMenu(docType) -- This function will call RouteTo on previous menu
    end)

    ISEEDocumentsMainMenu:Open({
        startupPage = inputPage
    })
end

-- Function to handle displaying a document
function ShowDocument(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
    -- Only open a new ID document page if it's not already open
    if not MyidOpen then
        -- Create or reset the page for viewing ID
        local DocumentPageShow = ISEEDocumentsMainMenu:RegisterPage("show:document")
        -- Register generic elements that do not change
        DocumentPageShow:RegisterElement('header', {
            value = Config.DocumentTypes[docType].displayName,
            slot = 'header'
        })
        DocumentPageShow:RegisterElement('line', {
            slot = 'header'
        })
        DocumentPageShow:RegisterElement("html", {
            slot = 'header',
            value = [[<img width="200px" height="200px" style="margin: 0 auto;" src="]] ..
                (picture or 'default_picture_url_here') .. [[" />]]
        })

        -- Register HTML element
        DocumentPageShow:RegisterElement("html", {
            value = {
                [[
                <div style="text-align: center; margin-top: 10px;">
                    <p><b>]] .. _U('Firstname').. [[</b> ]] .. (firstname or 'Unknown') .. [[</p>
                    <p><b>]] .. _U('Lastname').. [[</b> ]] .. (lastname or 'Unknown') .. [[</p>
                    <p><b>]] .. _U('Nickname').. [[</b> ]] .. (nickname or 'Unknown') .. [[</p>
                    <p><b>]] .. _U('Job').. [[</b> ]] .. (job or 'Unknown') .. [[</p>
                    <p><b>]] .. _U('Age').. [[</b> ]] .. (age or 'Unknown') .. [[</p>
                    <p><b>]] .. _U('Gender').. [[</b> ]] .. (gender or 'Unknown') .. [[</p>
                    <p><b>]] .. _U('CreationDate').. [[</b> ]] .. (date or 'Unknown') .. [[</p>
                    <p><b>]] .. _U('ExpiryDate').. [[</b> ]] .. (expire_date or 'N/A') .. [[</p>
                </div>
                ]]
            }
        })

        -- Flag the document as open and display it
        MyidOpen = true
        ISEEDocumentsMainMenu:Open({ startupPage = DocumentPageShow })
    else
        -- Simply close the document if it's already open (toggle functionality)
        ISEEDocumentsMainMenu:Close()
        MyidOpen = false
    end
end

-- Function to handle opening a document
function OpenDocument(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
    -- Only open a new ID document page if it's not already open
    if not MyidOpen then
        local DocumentPageOpen = ISEEDocumentsMainMenu:RegisterPage("open:document")

        DocumentPageOpen:RegisterElement('header', {
            value = Config.DocumentTypes[docType].displayName,
            slot = 'header'
        })
        DocumentPageOpen:RegisterElement('line', { slot = 'header' })
        DocumentPageOpen:RegisterElement("html", {
            slot = 'header',
            value = [[<img width="200px" height="200px" style="margin: 0 auto;" src="]] ..
                (picture or 'default_picture_url_here') .. [[" />]]
        })

        -- Register HTML element
        DocumentPageOpen:RegisterElement("html", {
            value = {
                [[
                <div style="text-align: center; margin-top: 10px;">
                    <p><b>]] .. _U('Firstname').. [[</b> ]] .. (firstname or 'Unknown') .. [[</p>
                    <p><b>]] .. _U('Lastname').. [[</b> ]] .. (lastname or 'Unknown') .. [[</p>
                    <p><b>]] .. _U('Nickname').. [[</b> ]] .. (nickname or 'Unknown') .. [[</p>
                    <p><b>]] .. _U('Job').. [[</b> ]] .. (job or 'Unknown') .. [[</p>
                    <p><b>]] .. _U('Age').. [[</b> ]] .. (age or 'Unknown') .. [[</p>
                    <p><b>]] .. _U('Gender').. [[</b> ]] .. (gender or 'Unknown') .. [[</p>
                    <p><b>]] .. _U('CreationDate').. [[</b> ]] .. (date or 'Unknown') .. [[</p>
                    <p><b>]] .. _U('ExpiryDate').. [[</b> ]] .. (expire_date or 'N/A') .. [[</p>
                </div>
                ]]
            }
        })

        -- Register actions
        DocumentPageOpen:RegisterElement('button', {
            label = _U('ShowDocument'),
            style = { ['border-radius'] = '6px' },
        }, function()
            TriggerServerEvent('isee-documents:server:showDocumentClosestPlayer', docType)
        end)
        DocumentPageOpen:RegisterElement('button', {
            label = _U('PutBack'),
            style = { ['border-radius'] = '6px' },
        }, function()
            ISEEDocumentsMainMenu:Close({
            })
        end)

        -- Flag the document as open and display it
        MyidOpen = true
        ISEEDocumentsMainMenu:Open({ startupPage = DocumentPageOpen })
    else
        -- Simply close the document if it's already open (toggle functionality)
        ISEEDocumentsMainMenu:Close()
        MyidOpen = false
    end
end

-- Register network event handler
RegisterNetEvent('isee-documents:opensubmenu')
AddEventHandler('isee:documents:opensubmenu', function(docType)
    OpenDocumentSubMenu(docType)
end)

RegisterNetEvent('isee-documents:client:opendocument')
AddEventHandler('isee-documents:client:opendocument', function(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
    OpenDocument(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
end)

RegisterNetEvent('isee-documents:client:addexpiry')
AddEventHandler('isee-documents:client:addexpiry', function(docType)
    AddExpiryDate(docType)
end)

RegisterNetEvent('isee-documents:client:showdocument')
AddEventHandler('isee-documents:client:showdocument', function(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
    ShowDocument(docType, firstname, lastname, nickname, job, age, gender, date, picture, expire_date)
end)

RegisterNetEvent('isee-documents:client:noDocument')
AddEventHandler('isee-documents:client:noDocument', function()
    print("No document found for this type.")
end)

RegisterNetEvent('isee-documents:client:createDocument')
AddEventHandler('isee-documents:client:createDocument', function(docType)
    if docType then
        TriggerServerEvent('isee-documents:server:createDocument', docType)
    else
        print("Error: docType is missing.")
    end
end)

RegisterNetEvent('isee-documents:client:reissueDocument')
AddEventHandler('isee-documents:client:reissueDocument', function(docType)
    if docType then
        TriggerServerEvent('isee-documents:server:reissueDocument', docType)
    else
        print("Error: docType is missing.")
    end
end)

RegisterNetEvent('isee-documents:client:revokeDocument')
AddEventHandler('isee-documents:client:revokeDocument', function(docType)
    if docType then
        TriggerServerEvent('isee-documents:server:revokeDocument', docType)
    else
        print("Error: docType is missing.")
    end
end)

RegisterNetEvent('isee-documents:client:changephoto')
AddEventHandler('isee-documents:client:changephoto', function(docType)
    ChangeDocumentPhoto(docType)
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
