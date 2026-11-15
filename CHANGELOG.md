# Changelog

All notable changes to this project are documented here.

## [0.3.0-alpha] - 2026-11-15

### Added
- Exposed RK4 integration and sinusoidal oscillator helpers.
- Restored a Jacobi eigenvalue approximation for symmetric matrices.
- Public API for removing particles and adding spring constraints.
- Engine reset and lifecycle diagnostics.
- Particle creation options for initial velocity, fixed state, friction, and restitution.
- Documentation, examples, and initial TestEZ-style matrix tests.

### Changed
- Replaced array-length checks on GUID-keyed dictionaries with explicit counting.
- Added guards for zero-distance field calculations.
- Added maximum particle count and safer configuration defaults.
- Improved collision response and fixed-step catch-up handling.

### Fixed
- Heartbeat connection is disconnected when stopping or destroying the engine.
- Repeated `Start` calls no longer create multiple Heartbeat connections.
- Destroyed engine instances cannot be restarted.
- Removing a particle also removes its attached spring constraints.

### Notes
- This release is experimental and incomplete.
- The API may change without a compatibility guarantee.
