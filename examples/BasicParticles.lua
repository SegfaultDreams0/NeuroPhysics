-- demonstrates particle creation, force, impulse, and diagnostics
local Engine = require(game.ServerScriptService:WaitForChild("NeuroPhysics"))

Engine.Settings.Gravity = Vector3.new(0, -workspace.Gravity, 0)

local A = Engine.CreateParticle(Vector3.new(0, 18, 0), 1, 0.5)
local B = Engine.CreateParticle(Vector3.new(4, 18, 0), 1, 0.5)

Engine.AddSpring(A, B, 4, 35, 3)
Engine.ApplyImpulse(A, Vector3.new(-2, 0, 0))
Engine.Start()

task.wait(3)
print(Engine.Diagnostics())
Engine.Stop()
