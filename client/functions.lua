--Pulling Essentials
VORPcore = exports.vorp_core:GetCore()
BccUtils = exports['bcc-utils'].initiate()
FeatherMenu =  exports['feather-menu'].initiate()

ISEEDocumentsMainMenu = FeatherMenu:RegisterMenu('isee-documents:mainmenu', {
    top = '40%',  -- Adjust top position as needed
    left = '20%',  -- Position on the right side with 20px from the edge
    ['720width'] = '500px',
    ['1080width'] = '600px',
    ['2kwidth'] = '700px',
    ['4kwidth'] = '900px',
    style = {
        -- This style is a custom style, if you want to use it remove the -- otherwise you can use Feather-Menu default style
        --['background'] = 'linear-gradient(to bottom right, #514740, #261a0f)',
        --['border'] = '2px solid #d6c7b7',
        --['border-radius'] = '15px',
        --['box-shadow'] = '0px 8px 16px rgba(0, 0, 0, 0.5)',
        --['color'] = '#d6c7b7',
        --['font-family'] = 'Georgia, serif',
        --['font-size'] = '18px',
        --['padding'] = '20px',  -- Add padding around the menu
    },
    contentslot = {
        style = {
            ['height'] = '350px',
            ['min-height'] = '250px'
        }
    },
    draggable = true
})