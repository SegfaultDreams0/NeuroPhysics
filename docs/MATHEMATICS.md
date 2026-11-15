# Mathematical Notes

This document describes the simplified models used by the current prototype.

## Particle integration

For a particle with mass `m`, accumulated force `F`, and configured gravity `g`:

`a = g + F / m`

Velocity and position are updated using a semi-implicit Euler step:

`v(t + h) = v(t) + a h`

`x(t + h) = x(t) + v(t + h) h`

A damping multiplier is applied to velocity to reduce persistent motion.

## Spring force

For endpoints `A` and `B`, direction `n`, current distance `d`, rest length `L`, stiffness `k`, and relative speed along the spring `u`:

`F = n [k(d - L) + c u]`

The force is applied with opposite signs to the two endpoints.

## Neuron membrane update

The prototype uses a leaky membrane differential equation:

`dV/dt = (I + b - V/R) / C`

where `I` is input, `b` is bias, `R` is resistance, and `C` is capacitance. The implementation approximates the update using RK4 and converts membrane potential to activation using a logistic function.

## Entropy-like diagnostic

For activation `p`, the binary entropy expression is:

`H(p) = -p ln(p) - (1-p) ln(1-p)`

The engine reports the mean value across neurons. This is an activation-distribution diagnostic, not thermodynamic entropy.

## Discrete Fourier transform

For samples `x[j]`, the implementation computes:

`X[k] = (1/N) sum(x[j] exp(-i 2 pi k j / N))`

The direct implementation has quadratic time complexity, `O(N^2)`.


## Runge-Kutta integration

The exposed `RK4` helper uses the classical fourth-order Runge-Kutta method:

`k1 = f(x, t)`

`k2 = f(x + h k1 / 2, t + h / 2)`

`k3 = f(x + h k2 / 2, t + h / 2)`

`k4 = f(x + h k3, t + h)`

`x(t + h) = x(t) + h(k1 + 2k2 + 2k3 + k4)/6`

The generic helper requires a state type that supports addition and scalar multiplication. It is suitable for numbers and Vector3 values, but not arbitrary state tables.

## Jacobi eigenvalue approximation

`Matrix:EigenApproximation()` uses Jacobi rotations and therefore requires a real symmetric matrix. It returns an array of approximate eigenvalues and a matrix whose columns approximate the corresponding eigenvectors.
