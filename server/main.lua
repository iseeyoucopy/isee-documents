VORPcore = exports.vorp_core:GetCore()

-- Retrieve all document type keys from the Config.DocumentTypes table
local documentTypes = {}
for docType, _ in pairs(Config.DocumentTypes) do
    table.insert(documentTypes, docType)
end

-- Register each document type as a usable item
for _, docType in ipairs(documentTypes) do
    exports.vorp_inventory:registerUsableItem(docType, function(data)
        local src = data.source
        local User = VORPcore.getUser(src)

        if User then
            local Character = User.getUsedCharacter
            if Character then
                local charidentifier = Character.charIdentifier

                -- SQL query to fetch document data based on character identifier and document type
                MySQL.query('SELECT * FROM `isee_documents` WHERE charidentifier = ? AND doc_type = ?', {charidentifier, docType}, function(result)
                    if result and #result > 0 then
                        local doc = result[1]
                        TriggerClientEvent('isee-documents:client:opendocument', src, docType, doc.firstname, doc.lastname, doc.nickname, doc.job, doc.age, doc.gender, doc.date, doc.picture, doc.days)
                    else
                        print("No document found for type: " .. tostring(docType))
                        TriggerClientEvent('isee-documents:client:noDocument', src)
                    end
                end)
            else
                print("Error: Character data not found.")
            end
        else
            print("Error: User not found for source.")
        end
    end)
end

RegisterServerEvent('isee-documents:server:createDocument')
AddEventHandler('isee-documents:server:createDocument', function(docType)
    local src = source
    local Character = VORPcore.getUser(src).getUsedCharacter
    local charidentifier = Character.charIdentifier
    local Money = Character.money
    local price = Config.DocumentTypes[docType].price -- Access the price for the specific document type

    -- Create a date string
    local date = os.date('%Y-%m-%d %H:%M:%S')  -- Standard SQL datetime format

    -- Default picture, assuming you have a default image for each document type in Config
    local picture = Config.DocumentTypes[docType].defaultPicture

    MySQL.query('SELECT * FROM isee_documents WHERE charidentifier = ? AND doc_type = ?', {charidentifier, docType}, function(result)
        if result and result[1] then
            VORPcore.NotifyLeft(src, _U('AlreadyGotDocument'), "", Config.Textures.tick[1], Config.Textures.tick[2], 5000) -- Assumes translation for a generic document
        else
            if Money >= price then
                if exports.vorp_inventory:canCarryItems(src, 1) and exports.vorp_inventory:canCarryItem(src, docType, 1) then
                    MySQL.insert('INSERT INTO isee_documents (identifier, charidentifier, doc_type, firstname, lastname, nickname, job, age, gender, date, picture) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                    {
                        Character.identifier, charidentifier, docType,
                        Character.firstname, Character.lastname, Character.nickname,
                        Character.jobLabel, Character.age, Character.gender,
                        date, picture
                    }, function()
                        Character.removeCurrency(0, price)
                        VORPcore.NotifyLeft(src, _U('BoughtDocument') .. price .. '$', "", Config.Textures.tick[1], Config.Textures.tick[2], 5000)
                        exports.vorp_inventory:addItem(src, docType, 1)
                    end)
                else
                    VORPcore.NotifyLeft(src, _U('PocketFull'), "", Config.Textures.cross[1], Config.Textures.cross[2], 5000)
                end
            else
                VORPcore.NotifyLeft(src, _U('NotEnoughMoney'), "", Config.Textures.cross[1], Config.Textures.cross[2], 5000)
            end
        end
    end)
end)

RegisterServerEvent('isee-documents:server:reissueDocument')
AddEventHandler('isee-documents:server:reissueDocument', function(docType)
    --print("Received docType: ", docType)  -- Debug print
    if docType == nil or Config.DocumentTypes[docType] == nil then
        print("Invalid or missing docType")  -- More debug info
        return
    end
    local src = source
    local Character = VORPcore.getUser(src).getUsedCharacter
    local charidentifier = Character.charIdentifier
    local Money = Character.money
    local docReissuePrice = Config.DocumentTypes[docType].reissuePrice

    -- Check if the document exists in the database
    MySQL.query('SELECT * FROM isee_documents WHERE charidentifier = ? AND doc_type = ?', {charidentifier, docType}, function(result)
        if result and result[1] then
            -- Check if the player has enough money to pay for the reissue fee
            if Money >= docReissuePrice then
                -- Check if the player can carry the document item
                if exports.vorp_inventory:canCarryItems(src, 1) and exports.vorp_inventory:canCarryItem(src, docType, 1) then
                    exports.vorp_inventory:addItem(src, docType, 1)
                    Character.removeCurrency(0, docReissuePrice)
                    VORPcore.NotifyLeft(src, _U('GotNewDocument') .. docReissuePrice ..'$', "", Config.Textures.tick[1], Config.Textures.tick[2], 5000)
                else
                    VORPcore.NotifyLeft(src, _U('PocketFull'), "", Config.Textures.cross[1], Config.Textures.cross[2], 5000)
                end
            else
                VORPcore.NotifyLeft(src, _U('NotEnoughMoney'), "", Config.Textures.cross[1], Config.Textures.cross[2], 5000)
            end
        else
        VORPcore.NotifyLeft(src, _U('GotNoDocument'), "", Config.Textures.cross[1], Config.Textures.cross[2], 5000)
        end
    end)
end)

RegisterServerEvent('isee-documents:server:revokeDocument')
AddEventHandler('isee-documents:server:revokeDocument', function(docType)
    local src = source
    local Character = VORPcore.getUser(src).getUsedCharacter
    local MyPedId = GetPlayerPed(src)
    local MyCoords = GetEntityCoords(MyPedId)

    for _, player in ipairs(GetPlayers()) do
        local ClosestCharacter = VORPcore.getUser(player).getUsedCharacter
        local PlayerPedId = GetPlayerPed(player)
        local PlayerCoords = GetEntityCoords(PlayerPedId)
        local Dist = #(MyCoords - PlayerCoords)

        if Dist > 0.3 and Dist < 3.0 then
            local closestidentifier = ClosestCharacter.identifier
            MySQL.query('SELECT * FROM isee_documents WHERE identifier = ? AND doc_type = ?', {closestidentifier, docType}, function(result)
                if result[1] ~= nil then
                    MySQL.execute('DELETE FROM isee_documents WHERE identifier = ? AND doc_type = ?', {closestidentifier, docType}, function()
                        local itemCount = exports.vorp_inventory:getItemCount(player, docType)
                        if itemCount > 0 then
                            exports.vorp_inventory:subItem(player, docType, 1)
                        end
                        VORPcore.NotifyLeft(src, _U('YouRevokedDocument'), "", Config.Textures.cross[1], Config.Textures.cross[2], 4000)
                        VORPcore.NotifyLeft(src, _U('RevokedDocument'), "", Config.Textures.cross[1], Config.Textures.cross[2], 4000)
                    end)
                else
                    VORPcore.NotifyLeft(src, _U('PlayerGotNoDocument'), "", Config.Textures.cross[1], Config.Textures.cross[2], 5000)
                end
            end)
        elseif Dist >= 3.0 then
            VORPcore.NotifyLeft(src, _U('NoNearbyPlayer'), "", Config.Textures.cross[1], Config.Textures.cross[2], 5000)
        end
    end
end)

RegisterServerEvent('isee-documents:server:changeDocumentPhoto')
AddEventHandler('isee-documents:server:changeDocumentPhoto', function(docType, photoLink)
    local src = source
    local Character = VORPcore.getUser(src).getUsedCharacter
    local charidentifier = Character.charIdentifier
    local Money = Character.money

    -- Access the changePhotoPrice using the correct path
    local photoChangePrice = Config.DocumentTypes[docType].changePhotoPrice

    -- Check if the document exists in the database
    MySQL.query('SELECT * FROM isee_documents WHERE charidentifier = ? AND doc_type = ?', {charidentifier, docType}, function(result)
        if result and result[1] then
            -- Check if the player has enough money to pay for the photo change fee
            if Money >= photoChangePrice then
                Character.removeCurrency(0, photoChangePrice)
                VORPcore.NotifyLeft(src, _U('ChangedPicture') .. photoChangePrice ..'$', "", Config.Textures.tick[1], Config.Textures.tick[2], 5000)
                -- Update the photo in the database
                MySQL.update('UPDATE isee_documents SET picture = ? WHERE charidentifier = ? AND doc_type = ?', {photoLink, charidentifier, docType})
            else
                VORPcore.NotifyLeft(src, _U('NotEnoughMoney'), "", Config.Textures.cross[1], Config.Textures.cross[2], 4000)
            end
        else
            VORPcore.NotifyLeft(src, _U('NoDocumentFound'), "", Config.Textures.cross[1], Config.Textures.cross[2], 5000)
        end
    end)
end)

RegisterServerEvent('isee-documents:server:showDocumentClosestPlayer')
AddEventHandler('isee-documents:server:showDocumentClosestPlayer', function(docType)
    local src = source
    local Character = VORPcore.getUser(src).getUsedCharacter
    local charidentifier = Character.charIdentifier
    local MyPedId = GetPlayerPed(src)
    local MyCoords = GetEntityCoords(MyPedId)
    MySQL.query('SELECT * FROM `isee_documents` WHERE charidentifier = ? AND doc_type = ?', {charidentifier, docType}, function(result)
        if result and #result > 0 then
            local doc = result[1]
            local closestPlayer, closestDistance = nil, math.huge

            for _, playerId in ipairs(GetPlayers()) do
                local playerPedId = GetPlayerPed(playerId)
                local playerCoords = GetEntityCoords(playerPedId)
                local distance = #(MyCoords - playerCoords)

                if distance < closestDistance and distance <= 3.0 and distance > 0.3 and playerId ~= src then
                    closestPlayer, closestDistance = playerId, distance
                end
            end
            print("Doc fetched with expire date:", doc.expire_date) 
            if closestPlayer then
                TriggerClientEvent('isee-documents:client:showdocument', closestPlayer, docType, doc.firstname, doc.lastname, doc.nickname, doc.job, doc.age, doc.gender, doc.date, doc.picture, doc.expire_date)
            else
                VORPcore.NotifyLeft(src, _U('NoNearbyPlayer'), "", Config.Textures.cross[1], Config.Textures.cross[2], 5000)
            end
        else
            VORPcore.NotifyLeft(src, "No document found", "", Config.Textures.cross[1], Config.Textures.cross[2], 5000)
        end
    end)
end)

RegisterNetEvent('isee-documents:server:updateExpiryDate')
AddEventHandler('isee-documents:server:updateExpiryDate', function(docType, daysToAdd)
    local src = source
    local Character = VORPcore.getUser(src).getUsedCharacter
    local charidentifier = Character.charIdentifier
    local Money = Character.money

    local extendChangePrice = Config.DocumentTypes[docType].extendPrice

    local date = os.date('%Y-%m-%d %H:%M:%S')
    -- Check if the document exists in the database
    MySQL.query('SELECT * FROM isee_documents WHERE charidentifier = ? AND doc_type = ?', {charidentifier, docType}, function(result)
        
        if result and result[1] then
            if Money >= extendChangePrice then
                local days = tonumber(daysToAdd) or 0
                local newExpiryDate = os.date('%Y-%m-%d', os.time() + (days * 86400))
                MySQL.update('UPDATE isee_documents SET expire_date = ? WHERE charidentifier = ? AND doc_type = ?',
                              {newExpiryDate, charidentifier, docType}, function(affectedRows)
                    if affectedRows > 0 then
                        Character.removeCurrency(0, extendChangePrice)
                        VORPcore.NotifyLeft(src, _U('ExpiryDateExtended') .. newExpiryDate, "", Config.Textures.tick[1], Config.Textures.tick[2], 5000)
                    else
                        VORPcore.NotifyLeft(src, _U('ExpiryDateUpdateFailed'), "", Config.Textures.cross[1], Config.Textures.cross[2], 4000)
                    end
                end)
            else
                VORPcore.NotifyLeft(src, _U('NotEnoughMoney'), "", Config.Textures.cross[1], Config.Textures.cross[2], 4000)
            end
        else
            VORPcore.NotifyLeft(src, "No document found", "", Config.Textures.cross[1], Config.Textures.cross[2], 5000)
        end
    end)
end)


