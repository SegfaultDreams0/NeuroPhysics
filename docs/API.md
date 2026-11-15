# API Reference

The module returns an `Engine` table. The default network is created when the module is required.

## Lifecycle

### `Engine.Start()`
Starts the Heartbeat-driven fixed-step loop. Returns `false` if already running.

### `Engine.Stop()`
Stops the Heartbeat connection. Returns `false` if already stopped.

### `Engine.Reset()`
Stops the engine, clears simulation data, resets counters, and creates a fresh default network.

### `Engine.Destroy()`
Stops the engine and clears its internal tables. The destroyed instance cannot be restarted or reused.

### `Engine.Step(deltaTime)`
Runs one simulation step manually. `deltaTime` must be a positive number.

### `Engine.Diagnostics()`
Returns a snapshot containing time, iteration count, entity counts, energy, entropy, pending signals, and lifecycle state.

## Particles

- `Engine.CreateParticle(position, mass?, radius?, options?)` returns a particle ID.
- `Engine.RemoveParticle(id)` removes a particle and any spring constraints attached to it.
- `Engine.ApplyForce(id, force)` applies force for the next simulation step.
- `Engine.ApplyImpulse(id, impulse)` changes velocity immediately.
- `Engine.AddSpring(aId, bId, restLength?, stiffness?, damping?)` creates a spring constraint.

Particle options may include `Velocity`, `Restitution`, `Friction`, and `Fixed`.

## Neural utilities

- `Engine.CreateNeuron(layer?, position?)` returns a neuron ID.
- `Engine.Connect(sourceId, targetId, weight?, delay?)` creates or replaces a connection between two neurons.
- `Engine.Inject(values)` adds values to the default input layer.
- `Engine.BuildNetwork(inputCount, hiddenCount, outputCount)` creates and returns three layer-ID arrays.
- `Engine.Learn(reward?)` updates connection weights using the experimental plasticity rule.

## Memory and mathematics

- `Engine.Memory(key, value, importance?)` stores a deep copy of a value.
- `Engine.Recall(key)` returns a deep copy or `nil`.
- `Engine.Field(position)` calculates a simple field contribution from all particles.
- `Engine.Fourier(samples)` returns a discrete Fourier spectrum.
- `Engine.Optimize(function, parameters, learningRate, iterations)` performs finite-difference gradient descent.
- `Engine.Matrix` exposes the matrix helper class.

## Exposed state

`Engine.Nodes`, `Edges`, `Particles`, `Memories`, `Settings`, and `Fields` are exposed for inspection and configuration. Direct mutation of internal state is not recommended; these tables are exposed primarily for experimentation and debugging.


## Additional numerical helpers

- `Engine.RK4(function, state, time, deltaTime)` applies a classical fourth-order Runge-Kutta step. The state and derivative must support the arithmetic operations used by the integrator.
- `Engine.CreateOscillator(frequency, amplitude, phase?)` creates a sinusoidal oscillator descriptor.
- `Engine.EvaluateOscillator(oscillator, time)` evaluates that oscillator at a given time.
- `Engine.Matrix:EigenApproximation(iterations?)` estimates eigenvalues and eigenvectors of a real symmetric matrix using Jacobi rotations.
