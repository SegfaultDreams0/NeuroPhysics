-- demonstrates injecting values into the default input layer
local Engine = require(game.ServerScriptService:WaitForChild("NeuroPhysics"))

Engine.Start()

for _ = 1, 20 do
    Engine.Inject({0.2, 0.5, 0.8, 0.1, 0.4, 0.6, 0.3, 0.9})
    task.wait(0.1)
end

local Stats = Engine.Diagnostics()
print("Neurons:", Stats.Neurons)
print("Active neurons:", Stats.Active)
print("Connections:", Stats.Connections)

Engine.Stop()
