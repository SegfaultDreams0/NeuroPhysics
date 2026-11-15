-- polls diagnostic values without creating any visual objects.
local Engine = require(game.ServerScriptService:WaitForChild("NeuroPhysics"))

Engine.Start()

while true do
    task.wait(1)
    local Stats = Engine.Diagnostics()

    print(string.format(
        "t=%.2f | neurons=%d | particles=%d | edges=%d | entropy=%.4f",
        Stats.Time,
        Stats.Neurons,
        Stats.Particles,
        Stats.Connections,
        Stats.Entropy
    ))
end
