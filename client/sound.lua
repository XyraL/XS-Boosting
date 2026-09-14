Sound = {}

-- Every cue goes through here, so the player's mute switch and the server's
-- master switch are both checked in exactly one place.
function Sound.Play(key)
    if not Config.Sound.enabled then return end
    if Boost.settings.sounds == false then return end

    local cue = Config.Sound.cues[key]
    if not cue or cue == false then return end
    if not cue.set or not cue.name then return end

    PlaySoundFrontend(-1, cue.name, cue.set, true)
end

-- The clock warning fires once per contract rather than every tick.
local warned = false

function Sound.ResetClock()
    warned = false
end

CreateThread(function()
    while true do
        Wait(1000)

        local at = Config.Sound.timeWarningAt or 0
        local job = Boost.job

        if at > 0 and job and not job.finished then
            local left = (job.deadline or 0) - GetCloudTimeAsInt()

            if not warned and left > 0 and left <= at then
                warned = true
                Sound.Play('timeLow')
            end
        elseif not job then
            warned = false
        end
    end
end)
