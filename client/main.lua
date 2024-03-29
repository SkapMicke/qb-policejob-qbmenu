-- Variables
QBCore = exports['qb-core']:GetCoreObject()
isHandcuffed = false
cuffType = 1
isEscorted = false
PlayerJob = {}
local DutyBlips = {}

-- Functions
local function CreateDutyBlips(playerId, playerLabel, playerJob, playerLocation)
    local ped = GetPlayerPed(playerId)
    local blip = GetBlipFromEntity(ped)
    if not DoesBlipExist(blip) then
        if NetworkIsPlayerActive(playerId) then
            blip = AddBlipForEntity(ped)
        else
            blip = AddBlipForCoord(playerLocation.x, playerLocation.y, playerLocation.z)
        end
        SetBlipSprite(blip, 1)
        ShowHeadingIndicatorOnBlip(blip, true)
        SetBlipRotation(blip, math.ceil(playerLocation.w))
        SetBlipScale(blip, 1.0)
        if playerJob == 'police' then
            SetBlipColour(blip, 38)
        else
            SetBlipColour(blip, 5)
        end
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(playerLabel)
        EndTextCommandSetBlipName(blip)
        DutyBlips[#DutyBlips + 1] = blip
    end

    if GetBlipFromEntity(PlayerPedId()) == blip then
        -- Ensure we remove our own blip.
        RemoveBlip(blip)
    end
end

-- Events

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        local player = QBCore.Functions.GetPlayerData()
        PlayerJob = player.job
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    local player = QBCore.Functions.GetPlayerData()
    PlayerJob = player.job
    isHandcuffed = false
    TriggerServerEvent('police:server:SetHandcuffStatus', false)
    TriggerServerEvent('police:server:UpdateBlips')
    TriggerServerEvent('police:server:UpdateCurrentCops')

    if player.metadata.tracker then
        local trackerClothingData = {
            outfitData = {
                ['accessory'] = {
                    item = 13,
                    texture = 0
                }
            }
        }
        TriggerEvent('qb-clothing:client:loadOutfit', trackerClothingData)
    else
        local trackerClothingData = {
            outfitData = {
                ['accessory'] = {
                    item = -1,
                    texture = 0
                }
            }
        }
        TriggerEvent('qb-clothing:client:loadOutfit', trackerClothingData)
    end

    if PlayerJob and PlayerJob.type ~= 'leo' then
        if DutyBlips then
            for _, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    TriggerServerEvent('police:server:UpdateBlips')
    TriggerServerEvent('police:server:SetHandcuffStatus', false)
    TriggerServerEvent('police:server:UpdateCurrentCops')
    isHandcuffed = false
    isEscorted = false
    PlayerJob = {}
    ClearPedTasks(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
    if DutyBlips then
        for _, v in pairs(DutyBlips) do
            RemoveBlip(v)
        end
        DutyBlips = {}
    end
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(newDuty)
    PlayerJob.onduty = newDuty
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    if JobInfo.type ~= 'leo' then
        if DutyBlips then
            for _, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
    end
    PlayerJob = JobInfo
    TriggerServerEvent('police:server:UpdateBlips')
end)

RegisterNetEvent('police:client:sendBillingMail', function(amount)
    SetTimeout(math.random(2500, 4000), function()
        local gender = Lang:t('info.mr')
        if QBCore.Functions.GetPlayerData().charinfo.gender == 1 then
            gender = Lang:t('info.mrs')
        end
        local charinfo = QBCore.Functions.GetPlayerData().charinfo
        TriggerServerEvent('qb-phone:server:sendNewMail', {
            sender = Lang:t('email.sender'),
            subject = Lang:t('email.subject'),
            message = Lang:t('email.message', { value = gender, value2 = charinfo.lastname, value3 = amount }),
            button = {}
        })
    end)
end)

RegisterNetEvent('police:client:UpdateBlips', function(players)
    if PlayerJob and (PlayerJob.type == 'leo' or PlayerJob.type == 'ems') and
            PlayerJob.onduty then
        if DutyBlips then
            for _, v in pairs(DutyBlips) do
                RemoveBlip(v)
            end
        end
        DutyBlips = {}
        if players then
            for _, data in pairs(players) do
                local id = GetPlayerFromServerId(data.source)
                CreateDutyBlips(id, data.label, data.job, data.location)
            end
        end
    end
end)

RegisterNetEvent('police:client:policeAlert', function(coords, text)
    local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street1name = GetStreetNameFromHashKey(street1)
    local street2name = GetStreetNameFromHashKey(street2)
    QBCore.Functions.Notify({ text = text, caption = street1name .. ' ' .. street2name }, 'police')
    PlaySound(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', 0, 0, 1)
    local transG = 250
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blip2 = AddBlipForCoord(coords.x, coords.y, coords.z)
    local blipText = Lang:t('info.blip_text', { value = text })
    SetBlipSprite(blip, 60)
    SetBlipSprite(blip2, 161)
    SetBlipColour(blip, 1)
    SetBlipColour(blip2, 1)
    SetBlipDisplay(blip, 4)
    SetBlipDisplay(blip2, 8)
    SetBlipAlpha(blip, transG)
    SetBlipAlpha(blip2, transG)
    SetBlipScale(blip, 0.8)
    SetBlipScale(blip2, 2.0)
    SetBlipAsShortRange(blip, false)
    SetBlipAsShortRange(blip2, false)
    PulseBlip(blip2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(blipText)
    EndTextCommandSetBlipName(blip)
    while transG ~= 0 do
        Wait(180 * 4)
        transG = transG - 1
        SetBlipAlpha(blip, transG)
        SetBlipAlpha(blip2, transG)
        if transG == 0 then
            RemoveBlip(blip)
            return
        end
    end
end)

RegisterNetEvent('police:client:SendToJail', function(time)
    TriggerServerEvent('police:server:SetHandcuffStatus', false)
    isHandcuffed = false
    isEscorted = false
    ClearPedTasks(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)
    TriggerEvent('prison:client:Enter', time)
end)

RegisterNetEvent('police:client:SendPoliceEmergencyAlert', function()
    local Player = QBCore.Functions.GetPlayerData()
    TriggerServerEvent('police:server:policeAlert', Lang:t('info.officer_down', { lastname = Player.charinfo.lastname, callsign = Player.metadata.callsign }))
    TriggerServerEvent('hospital:server:ambulanceAlert', Lang:t('info.officer_down', { lastname = Player.charinfo.lastname, callsign = Player.metadata.callsign }))
end)

-- Added

RegisterCommand('police_menu', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData.job and PlayerData.job.type == 'leo' then
        exports['qb-menu']:openMenu({
            {
                header = 'Police Menu',
                icon = 'fas fa-code',
                isMenuHeader = true,
            },
            {
                header = 'Show all menus',
                txt = 'Show all police menu',
                icon = 'fas fa-code-merge',
                params = {
                    event = 'qb-menu:client:allMenu',
                }
            },
            {
                header = 'Send to Jail',
                txt = 'jail player',
                icon = 'fas fa-code-merge',
                params = {
                    event = 'police:client:JailPlayer',
                }
            },
            {
                header = 'Release from Jail',
                txt = 'remove player!',
                icon = 'fas fa-code-pull-request',
                params = {
                    event = 'prison:client:UnjailPerson',
                    args = {
                        number = 2,
                    }
                }
            },
            {
                header = 'Clean Blood',
                txt = 'Clean Blood',
                icon = 'fas fa-code-pull-request',
                params = {
                    event = 'evidence:client:ClearBlooddropsInArea',
                    args = {
                        number = 3,
                    }
                }
            },
            {
                header = 'Seize Money',
                txt = 'Seize Money',
                icon = 'fas fa-code-pull-request',
                params = {
                    event = 'police:client:SeizeCash',
                    args = {
                        number = 4,
                    }
                }
            },
            {
                header = 'Take License Driver',
                txt = 'Take license',
                icon = 'fas fa-code-pull-request',
                params = {
                    event = 'police:client:SeizeDriverLicense',
                    args = {
                        number = 5,
                    }
                }
            },
            {
                header = 'Next',
                txt = 'Next Menu',
                icon = 'fas fa-code-pull-request',
                params = {
                    event = 'qb-menu:client:subMenu',
                    args = {
                        number = 6,
                    }
                }
            },
        })
    else
        QBCore.Functions.Notify("You do not have permission to access this menu")
    end
end, false)

RegisterKeyMapping('police_menu', 'Open Police Menu', 'keyboard', 'F6')


RegisterNetEvent('qb-menu:client:subMenu', function(data) --Object Menu
    exports['qb-menu']:openMenu({
        {
            header = 'Objects',
            icon = 'fa-solid fa-backward',
            params = {
                event = 'qb-menu:client:mainMenu',
                args = {
                    number = 1,
                }
            }
        },
        {
            header = 'Cone',
            txt = 'Spawn Cone!',
            icon = 'fas fa-code-merge',
            params = {
                event = 'police:client:spawnCone', 
                args = {
                    number = 2,
                }
            }
        },
        {
        header = 'Barrier',
        txt = 'Spawn Barrier!',
        icon = 'fas fa-code-merge',
        params = {
            event = 'police:client:spawnBarrier',
            args = {
                number = 3,
            }
        }
    },
    {
        header = 'Road Sign',
        txt = 'Spawn Road Sign!',
        icon = 'fas fa-code-merge',
        params = {
            event = 'police:client:spawnRoadSign',
            args = {
                number = 4,
            }
        }
    },
    {
        header = 'Tent',
        txt = 'Spawn Tent!',
        icon = 'fas fa-code-merge',
        params = {
            event = 'police:client:spawnTent',
            args = {
                number = 5,
            }
        }
    },
    {
        header = 'Light',
        txt = 'Spawn Light!',
        icon = 'fas fa-code-merge',
        params = {
            event = 'police:client:spawnLight',
            args = {
                number = 6,
            }
        }
    },
    {
        header = 'Spikes',
        txt = 'Spawn Spikes!',
        icon = 'fas fa-code-merge',
        params = {
            event = 'police:client:SpawnSpikeStrip',
            args = {
                number = 6,
            }
        }
    },
    {
        header = 'Delete Object',
        txt = 'Delete Objects',
        icon = 'fas fa-code-merge',
        params = {
            event = 'police:client:deleteObject',
            args = {
                number = 7,
            }
        }
    },
    {
        header = 'Next',
        txt = 'Next Menu',
        icon = 'fas fa-code-merge',
        params = {
            event = 'qb-menu:client:secMenu',
            args = {
                number = 8,
            }
        }
    },
    {
        header = 'Back',
        txt = 'Return to previous menu',
        icon = 'fas fa-code-merge',
        params = {
            event = 'qb-menu:client:mainMenu',
                  {
                }
            }
        }
    })
end)

RegisterNetEvent('qb-menu:client:secMenu', function(data) --Secondary Police Menu
    exports['qb-menu']:openMenu({
        {
            header = 'Secondary Police Menu',
            icon = 'fa-solid fa-backward',
            params = {
                event = 'qb-menu:client:secMenu',
            }
        },
        {
            header = 'Activate Cameras',
            txt = 'Activate Cameras',
            icon = 'fas fa-code-merge',
            params = {
                event = 'police:client:ActiveCamera',
            }
        },
        {
            header = 'Depot',
            txt = 'Activate Cameras',
            icon = 'fas fa-code-merge',
            params = {
                event = 'qb-menu:client:depotMenu',
            }
        },
        {
            header = 'Back',
            txt = 'Back To The Second Menu',
            icon = 'fas fa-code-pull-request',
            params = {
                event = 'qb-menu:client:subMenu',
                {
                }
            }
        }
    })
end)

RegisterNetEvent('qb-menu:client:depotMenu', function(data)
    exports['qb-menu']:openMenu({
        {
            header = 'Impound',
            icon = 'fa-solid fa-backward',
            params = {
                event = 'qb-menu:client:depotMenu',
            }
        },
        {
            header = 'Depot',
            txt = 'Impound a vehicle for a specified price',
            icon = 'fas fa-code-merge',
            params = {
                event = 'police:client:ImpoundVehicle',
            },
            dialog = function()
                local setheader = "Impound Vehicle"
                local setinputs = {
                    {
                        text = "Citizen ID (#)",
                        name = "citizenid",
                        type = "text",
                        isRequired = true,
                    },
                    {
                        text = "Price",
                        name = "price",
                        type = "number",
                        isRequired = true,
                    },
                }
                return exports['qb-input']:ShowInput({ header = setheader, txt = "Enter the Citizen ID and Price to impound the vehicle", inputs = setinputs })
            end,
            event = function(data)
                if data.citizenid ~= nil and data.price ~= nil then
                    TriggerServerEvent('police:server:ImpoundVehicle', data.citizenid, data.price)
                else
                    QBCore.Functions.Notify("Citizten  ID or Price is missing!", "error")
                end
            end
        }
    })
end, false)

RegisterNetEvent('qb-menu:client:allMenu', function(data) --Secondary Police Menu
    exports['qb-menu']:openMenu({
        {
            header = 'Secondary Police Menu',
            icon = 'fa-solid fa-backward',
            params = {
                event = 'qb-menu:client:allMenu',
            }
        },
        {
            header = 'Objects',
            txt = 'Objects Police Menu',
            icon = 'fas fa-code-merge',
            params = {
                event = 'qb-menu:client:subMenu',
            }
        },
        {
            header = 'Second Police menu',
            txt = 'Second Police menu',
            icon = 'fas fa-code-merge',
            params = {
                event = 'qb-menu:client:secMenu',
                {
                }
            }
        }
    })
end)

-- Threads
CreateThread(function()
    for _, station in pairs(Config.Locations['stations']) do
        local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
        SetBlipSprite(blip, 60)
        SetBlipAsShortRange(blip, true)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 29)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(station.label)
        EndTextCommandSetBlipName(blip)
    end
end)