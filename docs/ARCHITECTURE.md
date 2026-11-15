# Architecture

NeuroPhysics is organized as a single ModuleScript at this stage. The code is grouped internally by responsibility so it can later be split into smaller modules without changing the conceptual design.

## Subsystems

### Simulation lifecycle
A fixed-step accumulator drives simulation updates from `RunService.Heartbeat`. The loop limits catch-up work using `MaxSteps` to reduce the risk of a spiral of death after a long frame.

### Particle simulation
Particles store position, previous position, velocity, acceleration, force, mass, and collision properties. Forces are accumulated and consumed during the next step. Springs add forces to connected particles.

### Neural dynamics
Neurons use a simplified leaky integrate-and-fire-inspired membrane update. Edges carry weights and optional signal delays. Signals are queued and delivered when their arrival time is reached.

### Plasticity
A small reward-modulated correlation rule adjusts edge weights. This is an experimental learning mechanism, not backpropagation and not a complete machine-learning algorithm.

### Memory
Memory entries are stored in a Lua table with importance, strength, timestamp, and retrieval count. Strength decays over simulation time.

### Mathematical helpers
The project includes basic matrix operations, a discrete Fourier transform, and finite-difference optimization helpers.

## Data flow

1. Heartbeat adds elapsed time to the accumulator.
2. The fixed-step loop processes due neural signals.
3. Neurons update their membrane state and may emit signals.
4. Spring constraints apply forces to particles.
5. Particles integrate forces and resolve simple raycast collisions.
6. Plasticity and memory decay are updated.
7. Diagnostics are recalculated.

## Design constraints

The current implementation prioritizes readability and experimentation over maximum throughput. It uses Lua tables and per-particle raycasts, so large simulations can become expensive. A future modular version could separate the solver, neural network, memory, and math utilities into independent modules.
