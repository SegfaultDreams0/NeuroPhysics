--!nonstrict

--[[ 
    neuroPhysics
    experimental neural-dynamics and particle-physics toolkit for Roblox
    this project is a work in progress APIs and simulation behaviour may change
    by bighnika akene @towlerblio
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local Engine = {}
local Nodes = {}
local Edges = {}
local Particles = {}
local Memories = {}
local Signals = {}
local Constraints = {}
local Fields = {}

local Clock = 0
local Accumulator = 0
local Iteration = 0
local Energy = 0
local Entropy = 0
local Running = false
local Destroyed = false
local HeartbeatConnection = nil

local Settings = {
    Step = 1 / 120,
    MaxSteps = 8,
    Gravity = Vector3.new(0, -196.2, 0),
    Damping = 0.994,
    MaximumNodes = 512,
    MaximumParticles = 2048,
    MaximumVelocity = 500,
    MaximumEnergy = 100000,
    Plasticity = 0.003,
    Epsilon = 1e-6,
    CollisionEnabled = true,
    CollisionFilter = {},
}

local Random = Random.new()

local function GUID()
    return HttpService:GenerateGUID(false)
end

local function Clamp(Value, Minimum, Maximum)
    return math.max(Minimum, math.min(Maximum, Value))
end

local function Normalize(Value)
    if Value.Magnitude <= Settings.Epsilon then
        return Vector3.zero
    end
    return Value.Unit
end

local function Reflect(Velocity, Normal)
    return Velocity - 2 * Velocity:Dot(Normal) * Normal
end

local function DeepCopy(Value, Cache)
    if type(Value) ~= "table" then
        return Value
    end

    Cache = Cache or {}
    if Cache[Value] then
        return Cache[Value]
    end

    local Result = {}
    Cache[Value] = Result

    for Key, Item in pairs(Value) do
        Result[DeepCopy(Key, Cache)] = DeepCopy(Item, Cache)
    end

    return setmetatable(Result, getmetatable(Value))
end

local function Count(Dictionary)
    local Total = 0
    for _ in pairs(Dictionary) do
        Total += 1
    end
    return Total
end

local function AssertAlive()
    assert(not Destroyed, "NeuroPhysics has been destroyed")
end

-- matrix utilities 

local Matrix = {}
Matrix.__index = Matrix

function Matrix.new(Rows, Columns, InitialValue)
    assert(Rows > 0 and Columns > 0, "Matrix dimensions must be positive")

    local Self = setmetatable({
        Rows = Rows,
        Columns = Columns,
        Data = {},
    }, Matrix)

    for Row = 1, Rows do
        Self.Data[Row] = table.create(Columns, InitialValue or 0)
    end

    return Self
end

function Matrix:Identity()
    assert(self.Rows == self.Columns, "Identity requires a square matrix")
    for Row = 1, self.Rows do
        for Column = 1, self.Columns do
            self.Data[Row][Column] = Row == Column and 1 or 0
        end
    end
    return self
end

function Matrix:Transpose()
    local Result = Matrix.new(self.Columns, self.Rows)
    for Row = 1, self.Rows do
        for Column = 1, self.Columns do
            Result.Data[Column][Row] = self.Data[Row][Column]
        end
    end
    return Result
end

function Matrix:Multiply(Other)
    assert(self.Columns == Other.Rows, "Incompatible matrix dimensions")
    local Result = Matrix.new(self.Rows, Other.Columns)

    for Row = 1, self.Rows do
        for K = 1, self.Columns do
            local A = self.Data[Row][K]
            for Column = 1, Other.Columns do
                Result.Data[Row][Column] += A * Other.Data[K][Column]
            end
        end
    end

    return Result
end

function Matrix:Determinant()
    assert(self.Rows == self.Columns, "Determinant requires a square matrix")
    local A = DeepCopy(self.Data)
    local N = self.Rows
    local Determinant = 1

    for Column = 1, N do
        local Pivot = Column
        for Row = Column + 1, N do
            if math.abs(A[Row][Column]) > math.abs(A[Pivot][Column]) then
                Pivot = Row
            end
        end

        if math.abs(A[Pivot][Column]) < Settings.Epsilon then
            return 0
        end

        if Pivot ~= Column then
            A[Column], A[Pivot] = A[Pivot], A[Column]
            Determinant = -Determinant
        end

        local PivotValue = A[Column][Column]
        Determinant *= PivotValue

        for Row = Column + 1, N do
            local Factor = A[Row][Column] / PivotValue
            for K = Column + 1, N do
                A[Row][K] -= Factor * A[Column][K]
            end
        end
    end

    return Determinant
end

function Matrix:Inverse()
    assert(self.Rows == self.Columns, "Inverse requires a square matrix")
    local N = self.Rows
    local A = DeepCopy(self.Data)
    local Inverse = Matrix.new(N, N):Identity()

    for Column = 1, N do
        local Pivot = Column
        for Row = Column + 1, N do
            if math.abs(A[Row][Column]) > math.abs(A[Pivot][Column]) then
                Pivot = Row
            end
        end

        if math.abs(A[Pivot][Column]) < Settings.Epsilon then
            return nil
        end

        A[Column], A[Pivot] = A[Pivot], A[Column]
        Inverse.Data[Column], Inverse.Data[Pivot] = Inverse.Data[Pivot], Inverse.Data[Column]

        local PivotValue = A[Column][Column]
        for K = 1, N do
            A[Column][K] /= PivotValue
            Inverse.Data[Column][K] /= PivotValue
        end

        for Row = 1, N do
            if Row ~= Column then
                local Factor = A[Row][Column]
                for K = 1, N do
                    A[Row][K] -= Factor * A[Column][K]
                    Inverse.Data[Row][K] -= Factor * Inverse.Data[Column][K]
                end
            end
        end
    end

    return Inverse
end


-- general numerical helpers

local function RK4(Function, State, Time, DeltaTime)
    local K1 = Function(State, Time)
    local K2 = Function(State + K1 * (DeltaTime * 0.5), Time + DeltaTime * 0.5)
    local K3 = Function(State + K2 * (DeltaTime * 0.5), Time + DeltaTime * 0.5)
    local K4 = Function(State + K3 * DeltaTime, Time + DeltaTime)

    return State + (K1 + K2 * 2 + K3 * 2 + K4) * (DeltaTime / 6)
end

local function CreateOscillator(Frequency, Amplitude, Phase)
    return {
        Frequency = Frequency,
        Amplitude = Amplitude,
        Phase = Phase or 0,
    }
end

local function EvaluateOscillator(Oscillator, Time)
    local AngularFrequency = 2 * math.pi * Oscillator.Frequency
    return Oscillator.Amplitude * math.sin(AngularFrequency * Time + Oscillator.Phase)
end


function Matrix:EigenApproximation(MaxIterations)
    assert(self.Rows == self.Columns, "Eigen approximation requires a square matrix")

    local N = self.Rows
    local A = DeepCopy(self.Data)
    local V = Matrix.new(N, N):Identity()

    -- Jacobi rotations assume a real symmetric matrix
    for Row = 1, N do
        for Column = Row + 1, N do
            assert(
                math.abs(A[Row][Column] - A[Column][Row]) < 1e-5,
                "EigenApproximation requires a symmetric matrix"
            )
        end
    end

    for _ = 1, MaxIterations or 32 do
        local P, Q, Maximum = 1, 1, 0

        for Row = 1, N do
            for Column = Row + 1, N do
                if math.abs(A[Row][Column]) > Maximum then
                    P, Q = Row, Column
                    Maximum = math.abs(A[Row][Column])
                end
            end
        end

        if Maximum < Settings.Epsilon then
            break
        end

        local Angle = 0.5 * math.atan2(
            2 * A[P][Q],
            A[Q][Q] - A[P][P]
        )
        local C = math.cos(Angle)
        local S = math.sin(Angle)

        local App = C * C * A[P][P] - 2 * S * C * A[P][Q] + S * S * A[Q][Q]
        local Aqq = S * S * A[P][P] + 2 * S * C * A[P][Q] + C * C * A[Q][Q]

        for K = 1, N do
            if K ~= P and K ~= Q then
                local Akp = A[K][P]
                local Akq = A[K][Q]
                A[K][P] = C * Akp - S * Akq
                A[P][K] = A[K][P]
                A[K][Q] = S * Akp + C * Akq
                A[Q][K] = A[K][Q]
            end

            local Vkp = V.Data[K][P]
            local Vkq = V.Data[K][Q]
            V.Data[K][P] = C * Vkp - S * Vkq
            V.Data[K][Q] = S * Vkp + C * Vkq
        end

        A[P][P] = App
        A[Q][Q] = Aqq
        A[P][Q] = 0
        A[Q][P] = 0
    end

    local Eigenvalues = table.create(N)
    for Index = 1, N do
        Eigenvalues[Index] = A[Index][Index]
    end

    return Eigenvalues, V
end

-- particle simulation

local RayParameters = RaycastParams.new()
RayParameters.FilterType = Enum.RaycastFilterType.Exclude
RayParameters.IgnoreWater = true

local function CreateParticle(Position, Mass, Radius, Options)
    AssertAlive()
    assert(typeof(Position) == "Vector3", "Position must be a Vector3")
    assert(Count(Particles) < Settings.MaximumParticles, "Maximum particle count reached")

    Options = Options or {}
    local ID = GUID()

    Particles[ID] = {
        ID = ID,
        Position = Position,
        PreviousPosition = Position,
        Velocity = Options.Velocity or Vector3.zero,
        Acceleration = Vector3.zero,
        Force = Vector3.zero,
        Mass = math.max(Mass or 1, Settings.Epsilon),
        Radius = math.max(Radius or 0.5, Settings.Epsilon),
        Restitution = Clamp(Options.Restitution or 0.5, 0, 1),
        Friction = Clamp(Options.Friction or 0.4, 0, 1),
        Fixed = Options.Fixed == true,
        KineticEnergy = 0,
        PotentialEnergy = 0,
    }

    return ID
end

local function RemoveParticle(ID)
    if not Particles[ID] then
        return false
    end

    Particles[ID] = nil

    for ConstraintID, Constraint in pairs(Constraints) do
        if Constraint.A == ID or Constraint.B == ID then
            Constraints[ConstraintID] = nil
        end
    end

    return true
end

local function ApplyForce(ID, Force)
    local Particle = Particles[ID]
    if Particle and not Particle.Fixed then
        Particle.Force += Force
        return true
    end
    return false
end

local function ApplyImpulse(ID, Impulse)
    local Particle = Particles[ID]
    if Particle and not Particle.Fixed then
        Particle.Velocity += Impulse / Particle.Mass
        return true
    end
    return false
end

local function AddSpring(A, B, RestLength, Stiffness, Damping)
    AssertAlive()
    assert(Particles[A] and Particles[B], "Both spring particles must exist")
    assert(A ~= B, "A spring cannot connect a particle to itself")

    local ID = GUID()
    Constraints[ID] = {
        ID = ID,
        A = A,
        B = B,
        Length = math.max(RestLength or (Particles[B].Position - Particles[A].Position).Magnitude, 0),
        Stiffness = math.max(Stiffness or 100, 0),
        Damping = math.max(Damping or 5, 0),
    }
    return ID
end

local function SolveSprings()
    for _, Spring in pairs(Constraints) do
        local A = Particles[Spring.A]
        local B = Particles[Spring.B]

        if A and B then
            local Delta = B.Position - A.Position
            local Distance = Delta.Magnitude
            if Distance > Settings.Epsilon then
                local Direction = Delta / Distance
                local RelativeSpeed = (B.Velocity - A.Velocity):Dot(Direction)
                local Magnitude = (Distance - Spring.Length) * Spring.Stiffness
                    + RelativeSpeed * Spring.Damping
                local Force = Direction * Magnitude
                ApplyForce(Spring.A, Force)
                ApplyForce(Spring.B, -Force)
            end
        end
    end
end

local function SolveCollision(Particle)
    if not Settings.CollisionEnabled then
        return
    end

    local Movement = Particle.Position - Particle.PreviousPosition
    local Distance = Movement.Magnitude
    if Distance <= Settings.Epsilon then
        return
    end

    local Result = Workspace:Raycast(
        Particle.PreviousPosition,
        Movement + Normalize(Movement) * Particle.Radius,
        RayParameters
    )

    if Result then
        local Normal = Result.Normal
        Particle.Position = Result.Position + Normal * Particle.Radius
        local NormalSpeed = Particle.Velocity:Dot(Normal)

        if NormalSpeed < 0 then
            local NormalVelocity = Normal * NormalSpeed
            local TangentialVelocity = Particle.Velocity - NormalVelocity
            Particle.Velocity = -NormalVelocity * Particle.Restitution
                + TangentialVelocity * (1 - Particle.Friction)
        end
    end
end

local function SimulateParticle(Particle, DeltaTime)
    if Particle.Fixed then
        Particle.Force = Vector3.zero
        return
    end

    Particle.PreviousPosition = Particle.Position
    local Acceleration = Settings.Gravity + Particle.Force / Particle.Mass

    Particle.Velocity += Acceleration * DeltaTime
    Particle.Velocity *= math.pow(Settings.Damping, DeltaTime * 60)

    local Speed = Particle.Velocity.Magnitude
    if Speed > Settings.MaximumVelocity then
        Particle.Velocity = Particle.Velocity.Unit * Settings.MaximumVelocity
    end

    Particle.Position += Particle.Velocity * DeltaTime
    SolveCollision(Particle)

    Particle.Acceleration = Acceleration
    Particle.Force = Vector3.zero
    Particle.KineticEnergy = 0.5 * Particle.Mass * Particle.Velocity:Dot(Particle.Velocity)
    Particle.PotentialEnergy = -Particle.Mass * Settings.Gravity:Dot(Particle.Position)
end

-- neural dynamics

local function CreateNeuron(Layer, Position)
    AssertAlive()
    assert(Count(Nodes) < Settings.MaximumNodes, "Maximum neuron count reached")

    local ID = GUID()
    Nodes[ID] = {
        ID = ID,
        Layer = Layer or 1,
        Position = Position or Vector3.zero,
        Potential = 0,
        Activation = 0,
        Bias = Random:NextNumber(-0.5, 0.5),
        Threshold = Random:NextNumber(0.5, 1),
        Resistance = Random:NextNumber(0.5, 2),
        Capacitance = Random:NextNumber(0.5, 2),
        Connections = {},
        Refractory = 0,
        SpikeCount = 0,
        LastSpike = 0,
        State = "DORMANT",
        Particle = nil,
    }

    return ID
end

local function ConnectNeurons(SourceID, TargetID, Weight, Delay)
    AssertAlive()
    local Source = Nodes[SourceID]
    local Target = Nodes[TargetID]
    assert(Source and Target, "Source and target neurons must exist")
    assert(SourceID ~= TargetID, "Self-connections are not supported")

    local Existing = Source.Connections[TargetID]
    if Existing then
        Edges[Existing] = nil
    end

    local ID = GUID()
    Edges[ID] = {
        ID = ID,
        Source = SourceID,
        Target = TargetID,
        Weight = Weight or Random:NextNumber(-1, 1),
        Delay = math.max(Delay or 0, 0),
        Plasticity = Settings.Plasticity,
        Trace = 0,
        Enabled = true,
    }
    Source.Connections[TargetID] = ID
    return ID
end

local function EmitSignal(SourceID, TargetID, Magnitude)
    local EdgeID = Nodes[SourceID] and Nodes[SourceID].Connections[TargetID]
    local Edge = EdgeID and Edges[EdgeID]

    if Edge and Edge.Enabled then
        table.insert(Signals, {
            Edge = EdgeID,
            Magnitude = Magnitude,
            Arrival = Clock + Edge.Delay,
            Target = TargetID,
        })
    end
end

local function ProcessSignals()
    local Pending = {}

    for _, Signal in ipairs(Signals) do
        if Signal.Arrival <= Clock then
            local Edge = Edges[Signal.Edge]
            local Target = Nodes[Signal.Target]
            if Edge and Target and Edge.Enabled then
                Target.Potential += Signal.Magnitude * Edge.Weight
                Edge.Trace += math.abs(Signal.Magnitude)
            end
        else
            table.insert(Pending, Signal)
        end
    end

    Signals = Pending
end

local function UpdateNeuron(Neuron, Input, DeltaTime)
    if Neuron.Refractory > 0 then
        Neuron.Refractory = math.max(0, Neuron.Refractory - DeltaTime)
        Neuron.Activation *= 0.9
        Neuron.State = "REFRACTORY"
        return
    end

    local Resistance = Neuron.Resistance
    local Capacitance = Neuron.Capacitance
    local function Derivative(Voltage)
        return (Input + Neuron.Bias - Voltage / Resistance) / Capacitance
    end

    local V = Neuron.Potential
    local K1 = Derivative(V)
    local K2 = Derivative(V + K1 * DeltaTime * 0.5)
    local K3 = Derivative(V + K2 * DeltaTime * 0.5)
    local K4 = Derivative(V + K3 * DeltaTime)
    Neuron.Potential += DeltaTime * (K1 + 2 * K2 + 2 * K3 + K4) / 6

    Neuron.Activation = 1 / (1 + math.exp(-Clamp(Neuron.Potential, -30, 30)))

    if Neuron.Activation >= Neuron.Threshold then
        Neuron.State = "FIRING"
        Neuron.SpikeCount += 1
        Neuron.LastSpike = Clock
        Neuron.Refractory = 0.025

        for TargetID in pairs(Neuron.Connections) do
            EmitSignal(Neuron.ID, TargetID, Neuron.Activation)
        end
    else
        Neuron.State = "RESTING"
    end
end

local function UpdatePlasticity(Reward)
    Reward = Reward or 0
    for _, Edge in pairs(Edges) do
        local Source = Nodes[Edge.Source]
        local Target = Nodes[Edge.Target]

        if Source and Target then
            local Correlation = Source.Activation * Target.Activation
            local Delta = Edge.Plasticity * (Correlation * Reward - Edge.Weight * 0.01)
            Edge.Weight = Clamp(Edge.Weight + Delta, -2, 2)
            Edge.Trace *= 0.97
        end
    end
end

local function CalculateEntropy()
    local Total = 0
    local CountNodes = 0

    for _, Neuron in pairs(Nodes) do
        local P = Clamp(Neuron.Activation, Settings.Epsilon, 1 - Settings.Epsilon)
        Total -= P * math.log(P) + (1 - P) * math.log(1 - P)
        CountNodes += 1
    end

    return CountNodes > 0 and Total / CountNodes or 0
end

local function CalculateSystemEnergy()
    local Total = 0
    for _, Particle in pairs(Particles) do
        Total += Particle.KineticEnergy + Particle.PotentialEnergy
    end
    return Total
end

-- memory and mathematical helpers 

local function CreateMemory(Key, Value, Importance)
    AssertAlive()
    assert(type(Key) == "string" and Key ~= "", "Memory key must be a non-empty string")

    Memories[Key] = {
        Value = DeepCopy(Value),
        Importance = Clamp(Importance or 0.5, 0, 1),
        Timestamp = Clock,
        Strength = 1,
        Retrievals = 0,
    }
end

local function RetrieveMemory(Key)
    local Memory = Memories[Key]
    if not Memory then
        return nil
    end

    Memory.Retrievals += 1
    Memory.Strength = Clamp(Memory.Strength + 0.01, 0, 1)
    return DeepCopy(Memory.Value)
end

local function UpdateMemories(DeltaTime)
    for Key, Memory in pairs(Memories) do
        Memory.Strength *= math.exp(-DeltaTime * (1 - Memory.Importance) * 0.01)
        if Memory.Strength < 0.001 then
            Memories[Key] = nil
        end
    end
end

local function ComputeField(Position)
    local Result = Vector3.zero

    for _, Particle in pairs(Particles) do
        local Delta = Position - Particle.Position
        local Distance = Delta.Magnitude
        if Distance > Settings.Epsilon then
            Result += (Delta / Distance) * (Particle.Mass / (Distance * Distance))
        end
    end

    return Result
end

local function FourierApproximation(Samples)
    local N = #Samples
    local Spectrum = {}
    if N == 0 then
        return Spectrum
    end

    for K = 0, N - 1 do
        local Real = 0
        local Imaginary = 0

        for J = 0, N - 1 do
            local Angle = 2 * math.pi * K * J / N
            Real += Samples[J + 1] * math.cos(Angle)
            Imaginary -= Samples[J + 1] * math.sin(Angle)
        end

        Real /= N
        Imaginary /= N
        Spectrum[K + 1] = {
            Real = Real,
            Imaginary = Imaginary,
            Magnitude = math.sqrt(Real * Real + Imaginary * Imaginary),
        }
    end

    return Spectrum
end

local function NumericalGradient(Function, Parameters, Delta)
    local Gradient = table.create(#Parameters, 0)
    for Index = 1, #Parameters do
        local Positive = table.clone(Parameters)
        local Negative = table.clone(Parameters)
        Positive[Index] += Delta
        Negative[Index] -= Delta
        Gradient[Index] = (Function(Positive) - Function(Negative)) / (2 * Delta)
    end
    return Gradient
end

local function Optimize(Function, Parameters, LearningRate, Iterations)
    local Result = table.clone(Parameters)
    for _ = 1, Iterations do
        local Gradient = NumericalGradient(Function, Result, 1e-4)
        for Index = 1, #Result do
            Result[Index] -= LearningRate * Gradient[Index]
        end
    end
    return Result
end

-- network construction

local function BuildNetwork(InputCount, HiddenCount, OutputCount)
    AssertAlive()
    assert(InputCount >= 1 and HiddenCount >= 1 and OutputCount >= 1, "Layer sizes must be positive")

    local Input, Hidden, Output = {}, {}, {}

    for Index = 1, InputCount do
        Input[Index] = CreateNeuron(1, Vector3.new(Index * 2, 10, 0))
    end
    for Index = 1, HiddenCount do
        Hidden[Index] = CreateNeuron(2, Vector3.new(Index * 2, 15, 0))
    end
    for Index = 1, OutputCount do
        Output[Index] = CreateNeuron(3, Vector3.new(Index * 2, 20, 0))
    end

    for _, A in ipairs(Input) do
        for _, B in ipairs(Hidden) do
            ConnectNeurons(A, B, Random:NextNumber(-0.5, 0.5), 0.002)
        end
    end
    for _, A in ipairs(Hidden) do
        for _, B in ipairs(Output) do
            ConnectNeurons(A, B, Random:NextNumber(-0.5, 0.5), 0.002)
        end
    end

    return Input, Hidden, Output
end

local InputLayer, HiddenLayer, OutputLayer = BuildNetwork(8, 24, 4)

local function InjectInputs(Values)
    AssertAlive()
    assert(type(Values) == "table", "Inputs must be an array")

    for Index, ID in ipairs(InputLayer) do
        local Neuron = Nodes[ID]
        if Neuron then
            Neuron.Potential += Values[Index] or 0
        end
    end
end

-- simulation lifecycle 

local function SimulationStep(DeltaTime)
    AssertAlive()
    assert(type(DeltaTime) == "number" and DeltaTime > 0, "DeltaTime must be positive")

    Clock += DeltaTime
    Iteration += 1

    ProcessSignals()
    for _, Neuron in pairs(Nodes) do
        UpdateNeuron(Neuron, 0, DeltaTime)
    end

    SolveSprings()
    for _, Particle in pairs(Particles) do
        SimulateParticle(Particle, DeltaTime)
    end

    UpdatePlasticity(0.5)
    UpdateMemories(DeltaTime)

    Entropy = CalculateEntropy()
    Energy = CalculateSystemEnergy()

    if math.abs(Energy) > Settings.MaximumEnergy then
        Fields.EnergyLimitReached = true
    else
        Fields.EnergyLimitReached = false
    end
end

local function GetDiagnostics()
    local Active = 0
    for _, Neuron in pairs(Nodes) do
        if Neuron.State == "FIRING" then
            Active += 1
        end
    end

    return {
        Time = Clock,
        Iterations = Iteration,
        Neurons = Count(Nodes),
        Active = Active,
        Particles = Count(Particles),
        Connections = Count(Edges),
        Constraints = Count(Constraints),
        Memories = Count(Memories),
        Energy = Energy,
        Entropy = Entropy,
        PendingSignals = #Signals,
        Running = Running,
        Destroyed = Destroyed,
    }
end

local function Start()
    AssertAlive()
    if Running then
        return false
    end

    Running = true
    HeartbeatConnection = RunService.Heartbeat:Connect(function(DeltaTime)
        if not Running or Destroyed then
            return
        end

        Accumulator += math.min(DeltaTime, 0.25)
        local Steps = 0

        while Accumulator >= Settings.Step and Steps < Settings.MaxSteps do
            SimulationStep(Settings.Step)
            Accumulator -= Settings.Step
            Steps += 1
        end

        if Steps >= Settings.MaxSteps and Accumulator >= Settings.Step then
            -- Drop excess accumulated time to avoid a permanent catch-up spiral.
            Accumulator = 0
        end
    end)

    return true
end

local function Stop()
    if not Running then
        return false
    end

    Running = false
    if HeartbeatConnection then
        HeartbeatConnection:Disconnect()
        HeartbeatConnection = nil
    end
    return true
end

local function Reset()
    AssertAlive()
    Stop()
    table.clear(Nodes)
    table.clear(Edges)
    table.clear(Particles)
    table.clear(Memories)
    table.clear(Signals)
    table.clear(Constraints)
    Clock = 0
    Accumulator = 0
    Iteration = 0
    Energy = 0
    Entropy = 0
    InputLayer, HiddenLayer, OutputLayer = BuildNetwork(8, 24, 4)
end

local function Destroy()
    if Destroyed then
        return
    end

    Stop()
    table.clear(Nodes)
    table.clear(Edges)
    table.clear(Particles)
    table.clear(Memories)
    table.clear(Signals)
    table.clear(Constraints)
    table.clear(Fields)
    Destroyed = true
end

-- public API 

Engine.Version = "0.3.0-alpha"
Engine.Nodes = Nodes
Engine.Edges = Edges
Engine.Particles = Particles
Engine.Memories = Memories
Engine.Settings = Settings
Engine.Fields = Fields
Engine.Matrix = Matrix
Engine.RK4 = RK4
Engine.CreateOscillator = CreateOscillator
Engine.EvaluateOscillator = EvaluateOscillator

Engine.Start = Start
Engine.Stop = Stop
Engine.Reset = Reset
Engine.Destroy = Destroy
Engine.Step = SimulationStep
Engine.Diagnostics = GetDiagnostics

Engine.Inject = InjectInputs
Engine.BuildNetwork = BuildNetwork
Engine.CreateNeuron = CreateNeuron
Engine.Connect = ConnectNeurons
Engine.Learn = UpdatePlasticity

Engine.CreateParticle = CreateParticle
Engine.RemoveParticle = RemoveParticle
Engine.ApplyForce = ApplyForce
Engine.ApplyImpulse = ApplyImpulse
Engine.AddSpring = AddSpring

Engine.Memory = CreateMemory
Engine.Recall = RetrieveMemory
Engine.Field = ComputeField
Engine.Optimize = Optimize
Engine.Fourier = FourierApproximation

return Engine
