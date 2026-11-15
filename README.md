# NeuroPhysics

NeuroPhysics is an experimental Luau project exploring a combination of neural dynamics, particle simulation, numerical methods, and lightweight memory utilities inside Roblox.

This repository is intentionally public because I wanted to share a portion of what I have been experimenting with and learning. **The project is not finished.** It is a work in progress, and its architecture, APIs, performance, and simulation behaviour may change as development continues.

## Project status

- Status: Work in progress
- Version: `0.3.0-alpha`
- Language: Luau
- Platform: Roblox
- Intended use: experimentation, learning, and prototyping

This is not a production-ready physics engine, a biological brain simulation, or a general-purpose machine-learning framework. The neural and physical models are simplified experiments.

## Current features

- Fixed-step simulation loop with a configurable step limit
- Particle state, force, impulse, gravity, damping, and basic raycast collision response
- Spring constraints between particles
- Leaky integrate-and-fire-inspired neuron dynamics
- Weighted neuron connections and delayed signal delivery
- Basic reward-modulated connection-weight adjustment
- Simple key-value memory with importance-based decay
- Particle-field calculation
- Discrete Fourier transform utility
- Numerical gradient and basic gradient-descent helper
- Matrix construction, multiplication, transpose, determinant, and inverse
- Runtime diagnostics and lifecycle controls

## Repository layout

```text
NeuroPhysics/
├── src/
│   └── NeuroPhysics.lua
├── docs/
│   ├── API.md
│   ├── ARCHITECTURE.md
│   └── MATHEMATICS.md
├── examples/
│   ├── BasicParticles.server.lua
│   ├── NeuralNetwork.server.lua
│   └── Diagnostics.server.lua
├── tests/
│   └── Matrix.spec.lua
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── README.md
└── .gitignore
```

## Installation

1. Copy `src/NeuroPhysics.lua` into your Roblox project as a `ModuleScript`.
2. Require the module from a server-side script or another suitable script.
3. Configure `NeuroPhysics.Settings` before starting the simulation.
4. Read the API and examples before using the experimental features.

Example:

```lua
local NeuroPhysics = require(
    game.ServerScriptService:WaitForChild("NeuroPhysics")
)

NeuroPhysics.Settings.Gravity = Vector3.new(0, -workspace.Gravity, 0)
NeuroPhysics.Start()

local particleId = NeuroPhysics.CreateParticle(
    Vector3.new(0, 15, 0),
    1,
    0.5
)

NeuroPhysics.ApplyImpulse(particleId, Vector3.new(5, 8, 0))
```

The module does not automatically create visible Roblox parts for particles. It simulates particle data; your game code is responsible for rendering that data if required.

## Basic usage

```lua
local Engine = require(path.to.NeuroPhysics)

local particle = Engine.CreateParticle(Vector3.new(0, 10, 0), 1, 0.5)
Engine.ApplyForce(particle, Vector3.new(0, 100, 0))

Engine.Start()

-- Later:
print(Engine.Diagnostics().Particles)
Engine.Stop()
```

For more examples, see the [`examples`](examples) directory.

## Configuration

The `Settings` table is exposed for experimentation. Common settings include:

| Setting | Default | Description |
|---|---:|---|
| `Step` | `1 / 120` | Fixed simulation timestep |
| `MaxSteps` | `8` | Maximum catch-up steps per Heartbeat |
| `Gravity` | `(0, -196.2, 0)` | Particle acceleration due to gravity |
| `Damping` | `0.994` | Per-frame-style velocity damping factor |
| `MaximumNodes` | `512` | Maximum neuron count |
| `MaximumParticles` | `2048` | Maximum particle count |
| `MaximumVelocity` | `500` | Particle speed limit |
| `CollisionEnabled` | `true` | Enables Workspace raycast collision checks |

Changing settings while the simulation is running can affect the next simulation step. Use sensible values and profile your experience.

## Important limitations

- Collision handling uses raycasts and a simplified radius offset; it is not a full spherecast-based rigid-body solver.
- Particle-particle collision is not implemented.
- Springs use a simple force model and may become unstable with extreme stiffness or large timesteps.
- Neural dynamics are simplified and are not intended to model real biological neurons.
- The learning rule is experimental and is not a trained neural-network implementation.
- The memory system is an in-memory utility, not persistent storage.
- The Fourier transform is a straightforward discrete implementation and may be expensive for large sample arrays.
- The numerical optimizer uses finite differences and is intended for small demonstrations.
- The default network is created when the module is required. Additional calls to `BuildNetwork` create additional neurons.
- The engine should generally be run on the server when its state must be authoritative.

## Testing

The `tests` directory contains a TestEZ-style example. It is a starting point, not a complete automated test suite. Run tests in a Roblox test environment with TestEZ available, and add coverage as the API evolves.

## Contributing

Suggestions, issue reports, and improvements are welcome. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a pull request.

## License

This project is released under the MIT License. See [`LICENSE`](LICENSE).

## A note 

I am sharing this project while it is still being developed because I wanted to make some of my experiments available to other Roblox developers. It is incomplete, and I do not claim that every system is optimized or fully validated. If you find an interesting use for it, have feedback, or spot something that could be improved, feel free to open an issue or share your thoughts.
#
