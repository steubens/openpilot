# Openpilot Codebase Reference
**twilsonco's Fork - Based on openpilot v0.8.9**

*Generated: 2025-11-06*
*Branch: staging*

---

## Table of Contents
1. [Overview](#overview)
2. [Directory Structure](#directory-structure)
3. [Architecture](#architecture)
4. [Build System](#build-system)
5. [Communication System](#communication-system)
6. [Main Components](#main-components)
7. [Car Integration](#car-integration)
8. [Custom Fork Features](#custom-fork-features)
9. [Development Workflow](#development-workflow)
10. [Key Files Reference](#key-files-reference)

---

## Overview

This is **twilsonco's custom fork** of comma.ai's openpilot, based on **version 0.8.9** from Winter 2021. The fork is specifically optimized for **GM vehicles**, particularly the **Chevy Volt** (2017-2018), and runs on Comma Two/Three devices.

### Key Characteristics
- **Base Version**: openpilot v0.8.9 (Winter 2021)
- **Target Hardware**: Comma Two, Comma Three, Comma Zero
- **Primary Vehicle**: Chevy Volt (2017-2018, also 2018 Acadia, supported Escalades)
- **OS**: AGNOS4 (for Comma 3)
- **Models**: Uses last of the "medium models" for path planning (0.8.12 lateral, 0.8.10 driver monitoring)
- **Language**: Python 3.8, C++17, C11
- **Compiler**: Clang

### Why This Fork?
- Rock-solid dependable medium models (vs newer models that cut corners)
- Extensive custom features for GM vehicles
- Active development with regular updates to `tw-staging` branch
- Strong Volt-specific optimizations

---

## Directory Structure

```
openpilot/
├── cereal/              # Messaging spec and libs (Cap'n Proto)
│   ├── log.capnp        # Main message definitions
│   ├── car.capnp        # Car-related messages
│   ├── services.py      # Service port/frequency definitions
│   ├── messaging/       # Messaging library implementation
│   └── visionipc/       # Vision IPC for camera frames
│
├── selfdrive/           # Core autonomous driving code
│   ├── assets/          # Fonts, images, sounds for UI
│   ├── athena/          # Communication with comma.ai app
│   ├── boardd/          # Communication with panda board
│   ├── camerad/         # Camera capture and processing
│   ├── car/             # Car-specific implementations
│   │   ├── gm/          # GM-specific code (MAIN FOCUS)
│   │   ├── honda/
│   │   ├── toyota/
│   │   └── [other brands]/
│   ├── controls/        # Planning, control, and decision logic
│   │   ├── controlsd.py   # Main control daemon
│   │   ├── plannerd.py    # Path planning
│   │   ├── radard.py      # Radar processing
│   │   └── lib/           # Control libraries
│   ├── locationd/       # Localization and vehicle parameter estimation
│   ├── loggerd/         # Data logging and uploading
│   ├── manager/         # Process manager (entry point)
│   ├── modeld/          # ML model runners (driving & monitoring)
│   ├── monitoring/      # Driver monitoring
│   ├── sensord/         # IMU interface
│   ├── thermald/        # Thermal management
│   ├── ui/              # User interface (Qt-based)
│   │   ├── paint.cc     # Main UI rendering
│   │   ├── ui.cc        # UI logic
│   │   └── qt/          # Qt UI components
│   └── test/            # Tests and simulator
│
├── opendbc/             # CAN database and parsing
│   ├── can/             # CAN message parser/packer
│   └── [brand]_*.dbc    # DBC files for each car brand
│
├── panda/               # Board firmware and communication
│   ├── board/           # STM32 firmware for panda board
│   ├── python/          # Python library for panda
│   └── tests/           # Hardware tests
│
├── common/              # Shared utility code
│   ├── params.py        # Parameter storage/retrieval
│   ├── op_params.py     # Custom opParams implementation
│   ├── realtime.py      # Real-time utilities
│   └── [various libs]
│
├── tools/               # Development and debugging tools
│   ├── replay/          # Log replay tools
│   ├── sim/             # CARLA simulator integration
│   └── [various scripts]
│
├── models/              # ML model files
├── laika/               # GPS positioning library (symlink)
├── rednose/             # Kalman filter library (symlink)
├── phonelibs/           # Phone/device libraries
├── pyextra/             # Extra Python packages
├── scripts/             # Utility scripts
├── installer/           # Installation scripts
├── docs/                # Documentation
├── external/            # External dependencies
│
├── SConstruct           # Main build file (SCons)
├── Pipfile              # Python dependencies
├── launch_openpilot.sh  # Main launch script
├── launch_chffrplus.sh  # Actual launch implementation
└── opparams.py          # opParams configuration tool
```

---

## Architecture

### System Overview

Openpilot is a **distributed system** of **daemon processes** that communicate via **publish-subscribe messaging** (cereal/Cap'n Proto). Each daemon is responsible for a specific aspect of autonomous driving.

### Process Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    manager.py (main)                         │
│          Launches and monitors all processes                 │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   ┌────▼────┐          ┌────▼────┐          ┌────▼────┐
   │ Hardware │          │ Sensors │          │ Control │
   │ Layer   │          │ & Inputs│          │ Layer   │
   └─────────┘          └─────────┘          └─────────┘
        │                     │                     │
   ┌────▼────┐          ┌────▼────┐          ┌────▼────┐
   │ boardd  │          │camerad  │          │controlsd│
   │ pandad  │          │modeld   │          │plannerd │
   │         │          │sensord  │          │radard   │
   └─────────┘          │locationd│          └─────────┘
                        └─────────┘                │
                                              ┌────▼────┐
                                              │   UI    │
                                              │ (Qt)    │
                                              └─────────┘
```

### Data Flow

```
1. Sensor Input:
   Camera → camerad → modeld → modelV2 message
   CAN Bus → boardd/pandad → carState message
   GPS/IMU → sensord → sensorEvents message
   Radar → radard → radarState message

2. Processing:
   modelV2 + carState + radarState → controlsd
   controlsd → lateralPlan + longitudinalPlan

3. Localization:
   sensorEvents + carState + cameraOdometry → locationd
   locationd → liveLocationKalman message

4. Control Output:
   controlsd → carControl message → boardd → panda → CAN Bus → Car

5. UI:
   All messages → ui → Display + Sound
```

---

## Build System

### SCons-Based Build

The project uses **SCons** (software construction tool) as its build system.

**Main build file**: `SConstruct`

### Key Build Targets

```bash
# Build everything
scons -j8

# Build specific components
scons selfdrive/controls/
scons selfdrive/ui/

# Build with options
scons --test              # Build tests
scons --asan              # Address sanitizer
scons --compile_db        # Generate compile_commands.json
```

### Build Configuration

- **Compiler**: Clang (CC/CXX)
- **C Standard**: C11 (`-std=gnu11`)
- **C++ Standard**: C++17 (`-std=c++1z`)
- **Optimization**: `-O2`
- **Position Independent Code**: `-fPIC`
- **Warnings as Errors**: `-Werror`

### Platform-Specific Builds

```python
# Darwin (macOS) - Development
arch = "Darwin"
- Uses Homebrew libraries (/opt/homebrew, /usr/local)
- OpenGL framework support

# aarch64 (Comma Two - Android)
arch = "aarch64"
- QCOM flag defined
- Android-specific paths
- SNPE ML framework

# larch64 (Comma Three - TICI)
arch = "larch64"
- QCOM2 flag defined
- Cortex-A57 optimization
- Wayland support
```

### Key Dependencies

**Python Packages** (from Pipfile):
- `pycapnp==1.1.0` - Cap'n Proto bindings
- `numpy` - Numerical computing
- `pyzmq` - ZeroMQ messaging
- `Cython` - C extensions
- `scons` - Build system
- `opencv-python` - Computer vision
- `requests` - HTTP library
- Qt5 - UI framework

**C/C++ Libraries**:
- Cap'n Proto - Serialization
- OpenCV - Computer vision
- ZMQ - Messaging transport
- Qt5 - UI framework
- SNPE - Qualcomm ML framework
- libyuv - Image conversion
- OpenCL - GPU compute

---

## Communication System

### Cereal - Message Passing

**Cereal** is the messaging layer built on **Cap'n Proto** (zero-copy serialization).

#### Message Definition

Messages are defined in `.capnp` files:
- `cereal/log.capnp` - Main messages (120+ message types)
- `cereal/car.capnp` - Car-specific messages

#### Service Registry

**File**: `cereal/services.py`

Defines all pub-sub services with:
- Port number (starting at 8001)
- Log flag (should this be logged?)
- Frequency (Hz)
- Decimation (logging rate reduction)

**Key Services** (selection):
```python
"carState": (True, 100., 10)         # 100Hz, log every 10th
"carControl": (True, 100., 10)       # Control commands
"controlsState": (True, 100., 10)    # Control state
"modelV2": (True, 20., 40)           # ML model output
"radarState": (True, 20., 5)         # Radar tracking
"lateralPlan": (True, 20., 5)        # Steering plan
"longitudinalPlan": (True, 20., 5)   # Speed/accel plan
"liveLocationKalman": (True, 20., 2) # Position estimate
"carEvents": (True, 1., 1)           # Events/alerts
```

#### Messaging API

```python
import cereal.messaging as messaging

# Publishing
pub = messaging.pub_sock('carControl')
msg = messaging.new_message('carControl')
msg.carControl.enabled = True
pub.send(msg.to_bytes())

# Subscribing
sub = messaging.sub_sock('carState')
msg = messaging.recv_one(sub)  # Blocking
# or
msg = messaging.recv_one_or_none(sub)  # Non-blocking
```

#### Message Types (Key Ones)

```
carState         - Current car state (speed, steering, buttons, etc.)
carControl       - Commands to car (gas, brake, steering)
carParams        - Car capabilities and parameters
carEvents        - Alerts and events
modelV2          - Driving model output (path, lanes, leads)
radarState       - Radar tracks
lateralPlan      - Lateral planning (steering)
longitudinalPlan - Longitudinal planning (speed)
controlsState    - Overall control state
liveLocationKalman - Kalman-filtered position
sensorEvents     - IMU data
deviceState      - Device status (CPU, memory, temp)
```

---

## Main Components

### 1. Manager (`selfdrive/manager/manager.py`)

**Entry Point**: Main process that launches and monitors all other processes.

**Responsibilities**:
- Initialize parameters
- Launch managed processes
- Monitor process health
- Handle crashes and restarts
- Update checks

**Process Configuration**: `selfdrive/manager/process_config.py`

### 2. Boardd (`selfdrive/boardd/`)

**Purpose**: Communication bridge with panda board

**Responsibilities**:
- Send/receive CAN messages via panda
- Set panda safety mode
- Monitor panda health
- Handle CAN message routing

**Key Files**:
- `boardd.py` - Main daemon
- `panda.py` - Panda interface

### 3. Camerad (`selfdrive/camerad/`)

**Purpose**: Camera capture and frame processing

**Implementation**: C++ for performance

**Responsibilities**:
- Capture frames from cameras (road, driver, wide)
- YUV format conversion
- Frame buffering
- Publish to `visionipc`

**Output**: Raw frames via shared memory (visionipc)

### 4. Modeld (`selfdrive/modeld/`)

**Purpose**: Run ML models for driving and monitoring

**Models**:
- **Driving Model** (0.8.12 lateral): Path prediction, lane lines, lead detection
- **Driver Monitoring Model** (0.8.10): Driver attention/drowsiness

**Input**: Camera frames from visionipc
**Output**: `modelV2` messages with predictions

**Implementation**: Uses SNPE (Snapdragon Neural Processing Engine) on device, ONNX on PC

### 5. Controlsd (`selfdrive/controls/controlsd.py`)

**Purpose**: Main control loop - decision making and actuation

**Frequency**: 100Hz

**Responsibilities**:
- Process all sensor inputs
- Run state machine (engaged/disengaged/etc.)
- Execute lateral control (steering)
- Execute longitudinal control (speed/accel)
- Generate alerts and events
- Safety checks

**Key Subsystems**:

#### Lateral Controllers (6 options):
Located in `selfdrive/controls/lib/`:
- `latcontrol_pid.py` - PID controller
- `latcontrol_indi.py` - Incremental Nonlinear Dynamic Inversion
- `latcontrol_lqr.py` - Linear Quadratic Regulator
- `latcontrol_torque.py` - Torque-based control
- `latcontrol_torque_indi.py` - Torque + INDI
- `latcontrol_torque_lqr.py` - Torque + LQR

**Default for GM**: Torque controller with custom Volt tuning

#### Longitudinal Control:
- `longcontrol.py` - Speed and acceleration control
- PID-based with configurable acceleration profiles
- Multiple modes: Normal, Sport, Eco

**Data Flow**:
```
Inputs:
  - carState (from boardd)
  - modelV2 (from modeld)
  - radarState (from radard)
  - lateralPlan (from plannerd)
  - longitudinalPlan (from plannerd)

Processing:
  - State machine
  - Lateral control
  - Longitudinal control
  - Safety checks

Outputs:
  - carControl (to boardd → car)
  - controlsState (status to UI)
```

### 6. Plannerd (`selfdrive/controls/plannerd.py`)

**Purpose**: Path and speed planning

**Responsibilities**:
- Lane planning (follow lanes or go laneless)
- Longitudinal planning (target speed/accel)
- Curve speed adjustment
- Map-based speed limit
- Dynamic lane positioning

**Output**:
- `lateralPlan` - Desired path
- `longitudinalPlan` - Desired speed/accel profile

### 7. Radard (`selfdrive/controls/radard.py`)

**Purpose**: Radar processing and lead vehicle tracking

**Frequency**: 20Hz

**Responsibilities**:
- Parse radar CAN messages
- Track objects over time
- Identify lead vehicle
- Provide lead distance/velocity
- Extended radar capabilities (this fork):
  - Track multiple vehicles
  - Adjacent lane traffic
  - Time-to-pass calculations

**Output**: `radarState` with lead info and all tracks

### 8. Locationd (`selfdrive/locationd/`)

**Purpose**: Precise localization using sensor fusion

**Responsibilities**:
- Kalman filter fusion of:
  - GPS
  - IMU (accelerometer, gyro)
  - Camera odometry
  - Wheel speed
- Vehicle parameter estimation
- Altitude estimation

**Output**: `liveLocationKalman` - High-precision position

**Implementation**: Uses **rednose** (Kalman filter library)

### 9. UI (`selfdrive/ui/`)

**Purpose**: User interface and driver feedback

**Framework**: Qt5 (C++)

**Key Files**:
- `ui.cc` - Main UI logic and state management
- `paint.cc` - Rendering (lane lines, path, lead, UI elements)
- `qt/` - Qt-specific widgets and windows

**Displays**:
- Road view with augmented reality
- Lane lines and driving path
- Lead vehicle indicator
- Speed and set speed
- Alerts and warnings
- Custom metrics (CPU, temp, distance, etc.)
- MADS status indicators
- Weather information
- Power meter / brake indicator

**Custom UI Features** (this fork):
- Touch controls for lane position
- Brightness control (tap driver monitor icon)
- Metric cycling (tap speed to change)
- Visual mode switching
- Extended radar visualization
- Coasting indicator

### 10. Pandad (`selfdrive/pandad.py`)

**Purpose**: High-level panda management

**Responsibilities**:
- Detect and initialize panda
- Publish panda status
- Handle firmware updates
- Set safety mode
- Monitor connection health

---

## Car Integration

### Car Interface Architecture

Each supported car brand has its own module in `selfdrive/car/[brand]/`.

### GM Implementation (`selfdrive/car/gm/`)

**Files**:
```
gm/
├── __init__.py
├── interface.py         # Main interface (CarInterface class)
├── carcontroller.py     # Builds CAN messages to send to car
├── carstate.py          # Parses CAN from car
├── values.py            # Constants, fingerprints, limits
├── radar_interface.py   # Radar integration (if applicable)
├── gmcan.py            # GM-specific CAN utilities
└── models/             # Per-model parameters
```

### Interface.py

**Class**: `CarInterface(CarInterfaceBase)`

**Key Methods**:
```python
@staticmethod
def get_params(candidate, fingerprint, ...):
    """Return CarParams for this vehicle"""

def update(self, c):
    """Called at 100Hz, update car state"""

def apply(self, c):
    """Called at 100Hz, send control commands"""
```

**Responsibilities**:
- Define car capabilities (steering, gas, brake ranges)
- Vehicle-specific tuning parameters
- Steering feedforward calculation
- Custom features (MADS, one-pedal, etc.)

### CarController.py

**Class**: `CarController`

**Purpose**: Generate CAN messages for car actuation

**Key Methods**:
```python
def update(self, enabled, CS, frame, actuators, ...):
    """Build CAN messages to send to car"""
```

**Outputs**: CAN messages for:
- Steering (EPS - Electric Power Steering)
- Acceleration/braking (ACC)
- HUD updates
- Buttons (fake button presses)

### CarState.py

**Class**: `CarState`

**Purpose**: Parse CAN messages from car

**Key Methods**:
```python
def update(self, pt_cp, cam_cp):
    """Parse CAN and update state"""
```

**Extracts**:
- Speed, acceleration
- Steering angle, torque
- Pedal positions (gas, brake)
- Button presses
- Gear position
- Turn signals
- Cruise control state
- Vehicle-specific data (Volt: battery voltage, current, etc.)

### Values.py

**Contains**:
- `CAR` enum - Supported models
- `FINGERPRINTS` - CAN fingerprints for identification
- `CarControllerParams` - Constants and limits
- `CruiseButtons` - Button definitions
- Safety limits (max steering angle, torque, etc.)

### Car Port Structure (Generic)

Every car implementation follows this pattern:

1. **Fingerprinting**: Identify car model from CAN messages
2. **CarParams**: Define capabilities and limits
3. **CarState**: Parse car's current state
4. **CarController**: Command the car
5. **Safety**: Enforce limits in both openpilot and panda

---

## Custom Fork Features

This fork includes extensive custom features beyond stock openpilot v0.8.9.

### MADS (Modified Assistive Driving Safety)

**Three independent features**:

1. **Autosteer**:
   - Always-on steering (even before engage)
   - Toggle with LKAS button
   - Visual indicator: colored steering wheel icon

2. **Lead Braking**:
   - Automatic braking for lead car (if no pedals pressed)
   - Toggle with ACC distance button
   - Visual indicator: white ring around MADS icon

3. **One-Pedal Driving** (Volt only):
   - Apply braking in L-mode when coasting
   - Toggle with double-press of regen paddle
   - Visual indicator: MADS icon color
   - **One-Pedal One-Time Stop**: Hold regen paddle below 5mph

**Files**:
- `selfdrive/car/gm/interface.py` - MADS logic
- `selfdrive/controls/controlsd.py` - Integration with control loop

### Dynamic Lane Positioning

**Manual Adjustment**:
- On-screen buttons to shift lane position
- Tap: 1/3 mile adjustment
- Double-tap: 10 mile adjustment
- Tap again to return to center

**Automatic Positioning**:
- Shift away from adjacent traffic
- Requires clear lane lines
- Activate: tap left then right (or right then left) within 2s
- **Auto-Auto mode**: Turns on automatically at 22mph+

**Files**:
- `selfdrive/controls/lib/lane_planner.py`
- `selfdrive/ui/paint.cc` - UI buttons

### Advanced Radar Features

**Extended Capabilities**:
- Brake for car in front of lead (prevent pile-ups)
- Indicate adjacent traffic (ongoing/oncoming)
- Track all cars (not just lead)
- Print speeds of all tracked cars
- Time-to-pass countdown for adjacent lanes

**Toggle**: Enable in settings
**Visual**: Blue dot over lead for extended range

**Files**:
- `selfdrive/controls/radard.py` - Enhanced tracking

### Acceleration Modes

**Three modes**: Normal, Sport, Eco
- Cycle with on-screen button
- Different acceleration curves
- Softer acceleration in Eco (good for traffic and curves)

**Files**:
- `selfdrive/controls/lib/longitudinal_planner.py`

### Coasting Mode

**Purpose**: Don't brake to maintain set speed (but still brake for lead/curves)

**Toggle** (Volt): D = coast, L = maintain speed
**Toggle** (Other): Tap max speed indicator

**Visual**: "+" after max speed when enabled

**Optional**: Upper speed limit (configurable)

**Files**:
- `selfdrive/car/gm/interface.py`
- `selfdrive/controls/controlsd.py`

### Weather Integration

**Uses OpenWeatherMap API**

**Features**:
- Display current weather
- Weather-based safety (far follow, mild accel in bad weather)
- Tap weather icon to cycle display modes

**Config**: API key in `/data/OpenWeatherMap_apiKey.txt`

**Files**:
- Custom weather daemon (not in standard location)

### Dynamic Metrics

**79 metrics to choose from**:
- Device: CPU temp/usage, memory, storage, GPS, altitude
- Vehicle: RPM, coolant temp, torque, acceleration, grade, EV power/efficiency
- Lead/Traffic: distances, speeds, follow counts
- Engagement: time/distance stats, disengagement counts

**Interact**: Tap current speed to cycle metrics, tap metric to change content

**Files**:
- `selfdrive/ui/paint.cc` - Rendering
- `selfdrive/ui/ui.cc` - Metric management

### opParams

**Command-line configuration tool**: `./opparams.py`

**Configure**:
- Acceleration profiles
- Follow distances
- Camera offset
- Coasting behavior
- Lane positioning
- Lateral controllers (6 options)
- UI metrics
- API keys
- And much more...

**Restart without reboot**: `./opparams.py -r` (Comma Three)

**Files**:
- `opparams.py` - Main tool
- `common/op_params.py` - Library

---

## Development Workflow

### Getting Started

**Requirements**:
- macOS (for development) or Linux
- Python 3.8
- Clang compiler
- SCons

**Setup**:
```bash
# Install Python dependencies
pipenv install

# Build the project
scons -j8

# Run tests
scons --test
pytest
```

### Running on Device

**SSH Access**:
```bash
ssh comma@192.168.x.x  # Device IP
password: [see comma docs]
```

**Locations**:
- Openpilot: `/data/openpilot/`
- Logs: `/data/media/0/realdata/`
- Parameters: `/data/params/`

**Restart openpilot**:
```bash
sudo reboot  # Full reboot
# or use opparams.py -r on C3
```

### Running on PC (Replay)

**Use comma's tools**:
```bash
# Install tools
pip install -e tools/

# Replay a route
tools/replay/replay '<route_name>'

# With UI
tools/sim/bridge.py  # In one terminal
./run_ui.sh           # In another
```

### Code Style

**Python**:
- PEP 8 compliant
- Use descriptive variable names
- Type hints encouraged

**C++**:
- Clang format (`.clang-format` in repo)
- C++17 features allowed

**Pre-commit Hooks**:
```bash
pre-commit install  # Install hooks
pre-commit run --all-files  # Run manually
```

### Testing

**Unit Tests**: In `selfdrive/test/`, `common/tests/`, etc.

**Run tests**:
```bash
pytest selfdrive/test/
```

**CI**: Jenkins (`.Jenkinsfile`) runs tests on commits

**Safety Tests**: Panda has extensive safety tests in `panda/tests/safety/`

### Debugging

**Logs**:
```bash
# View logs on device
tmux a  # Attach to tmux session with all processes

# Or individual processes
journalctl -u comma  # System logs
```

**Parameters**:
```bash
# Read parameter
cat /data/params/d/OpenpilotEnabledToggle

# Write parameter (use Python)
python
from common.params import Params
Params().put("SomeParam", "value")
```

**CAN Messages**:
```bash
# View CAN traffic
./selfdrive/debug/can_printer.py
```

**Model Visualization**:
```bash
# Visualize model output
./selfdrive/debug/model_replay.py '<route>'
```

---

## Key Files Reference

### Entry Points

| File | Description |
|------|-------------|
| `launch_openpilot.sh` | Main launch script (calls launch_chffrplus.sh) |
| `launch_chffrplus.sh` | Actual launch implementation |
| `selfdrive/manager/manager.py` | Process manager (Python entry point) |

### Core Control

| File | Description |
|------|-------------|
| `selfdrive/controls/controlsd.py` | Main control loop (100Hz) |
| `selfdrive/controls/plannerd.py` | Path and speed planning |
| `selfdrive/controls/radard.py` | Radar processing |
| `selfdrive/controls/lib/longcontrol.py` | Longitudinal controller |
| `selfdrive/controls/lib/latcontrol_*.py` | Lateral controllers (6 variants) |
| `selfdrive/controls/lib/drive_helpers.py` | Driving utilities |
| `selfdrive/controls/lib/longitudinal_planner.py` | Speed planning |
| `selfdrive/controls/lib/lane_planner.py` | Lane planning |

### Car Interface (GM)

| File | Description |
|------|-------------|
| `selfdrive/car/gm/interface.py` | GM car interface |
| `selfdrive/car/gm/carcontroller.py` | CAN message generation |
| `selfdrive/car/gm/carstate.py` | CAN message parsing |
| `selfdrive/car/gm/values.py` | Constants and limits |
| `selfdrive/car/gm/radar_interface.py` | Radar integration |

### Messaging

| File | Description |
|------|-------------|
| `cereal/log.capnp` | Main message definitions (Cap'n Proto) |
| `cereal/car.capnp` | Car-related messages |
| `cereal/services.py` | Service registry (ports, frequencies) |
| `cereal/messaging/__init__.py` | Messaging Python library |

### Hardware

| File | Description |
|------|-------------|
| `selfdrive/boardd/boardd.py` | Board communication daemon |
| `selfdrive/pandad.py` | Panda management |
| `panda/python/__init__.py` | Panda Python library |
| `panda/board/` | Panda firmware (C) |

### Camera & ML

| File | Description |
|------|-------------|
| `selfdrive/camerad/` | Camera capture (C++) |
| `selfdrive/modeld/` | Model runner (C++) |
| `models/` | Model files (.dlc, .onnx) |

### UI

| File | Description |
|------|-------------|
| `selfdrive/ui/ui.cc` | Main UI logic |
| `selfdrive/ui/paint.cc` | Rendering (lane lines, path, UI) |
| `selfdrive/ui/qt/` | Qt widgets |

### Utilities

| File | Description |
|------|-------------|
| `common/params.py` | Parameter storage API |
| `common/op_params.py` | opParams implementation |
| `common/realtime.py` | Real-time utilities |
| `selfdrive/config.py` | Global configuration |
| `selfdrive/version.py` | Version information |

### Configuration

| File | Description |
|------|-------------|
| `opparams.py` | Command-line configuration tool |
| `SConstruct` | Build configuration |
| `Pipfile` | Python dependencies |
| `.pre-commit-config.yaml` | Pre-commit hooks |

### Build

| File | Description |
|------|-------------|
| `SConstruct` | Main SCons build file |
| `site_scons/` | SCons build scripts |
| `*/SConscript` | Component-specific build files |

---

## Quick Reference Tables

### Key Constants

| Constant | Value | Location |
|----------|-------|----------|
| DT_CTRL | 0.01s (100Hz) | `common/realtime.py` |
| V_CRUISE_MIN | 25mph | `selfdrive/controls/lib/drive_helpers.py` |
| CAMERA_OFFSET | 0.04m | `selfdrive/controls/lib/lane_planner.py` |
| TRAJECTORY_SIZE | 33 points | `selfdrive/controls/lib/lane_planner.py` |

### Message Frequencies

| Message | Frequency | Purpose |
|---------|-----------|---------|
| carState | 100Hz | Current car state |
| carControl | 100Hz | Control commands |
| modelV2 | 20Hz | Driving model output |
| radarState | 20Hz | Radar tracking |
| lateralPlan | 20Hz | Steering plan |
| longitudinalPlan | 20Hz | Speed plan |
| liveLocationKalman | 20Hz | Position estimate |
| controlsState | 100Hz | Control state |

### CAN Bus Numbers (GM)

| Bus | Description |
|-----|-------------|
| 0 | Powertrain CAN |
| 1 | Chassis CAN (Steering, etc.) |
| 2 | Camera CAN (VOACC messages) |

---

## Tips and Tricks

### Performance

- **Reduce CPU**: Disable driver monitoring if not needed
- **Reduce data usage**: Enable "Disable onroad uploads" toggle
- **Battery optimization**: Adjust screen brightness (tap driver monitor icon)

### Debugging

- **View live params**: `watch -n 0.5 'ls -la /data/params/d/ | tail -20'`
- **Monitor CAN**: `./selfdrive/debug/can_printer.py`
- **Test panda**: `cd panda && python -c "from panda import Panda; print(Panda().health())"`

### Development

- **Quick edit-test cycle**: Edit on PC, rsync to device, restart
- **Use replay for testing**: Much faster than driving
- **Git branches**:
  - `tw-main`: Stable (1yr old base)
  - `tw-staging`: More updates (current)
  - `tw-dev`: Breaking changes

### Configuration

- **Use opparams**: Much easier than editing params via SSH
- **Backup params**: `tar -czf params_backup.tar.gz /data/params/`
- **Reset params**: Delete `/data/params/` and reboot

---

## Additional Resources

### Documentation

- **Comma Docs**: https://docs.comma.ai
- **openpilot Wiki**: https://github.com/commaai/openpilot/wiki
- **Fork README**: `README.md` (extensive feature documentation)
- **SAFETY**: `SAFETY.md` - Safety guidelines
- **CONTRIBUTING**: `CONTRIBUTING.md` - Contribution guide

### Community

- **Comma Discord**: https://discord.comma.ai
  - `#gm` channel
  - `twilsonco Volt GM fork` thread
- **openpilot Community Discord**: https://discord.gg/XnYqf6ZB9A
  - `#gm` channel
  - `twilsonco fork` thread
- **GitHub Issues**: https://github.com/twilsonco/openpilot/issues

### Tools

- **cabana**: CAN message browser (comma tool)
- **plotjuggler**: Time-series plotting (`tools/plotjuggler/`)
- **replay**: Drive replay (`tools/replay/`)
- **simulator**: CARLA integration (`tools/sim/`)

---

## Glossary

| Term | Definition |
|------|------------|
| **ACC** | Adaptive Cruise Control |
| **ALC** | Automated Lane Centering |
| **Cap'n Proto** | Zero-copy serialization format |
| **Cereal** | Openpilot's messaging system (built on Cap'n Proto) |
| **DBC** | CAN Database file format |
| **EPS** | Electric Power Steering |
| **INDI** | Incremental Nonlinear Dynamic Inversion |
| **LKAS** | Lane Keep Assist System |
| **LQR** | Linear Quadratic Regulator |
| **MADS** | Modified Assistive Driving Safety |
| **MPC** | Model Predictive Control |
| **Panda** | OBD-II dongle for CAN communication |
| **SCons** | Software Construction tool (build system) |
| **SNPE** | Snapdragon Neural Processing Engine |
| **TICI** | Comma Three device |
| **VisionIPC** | Shared memory system for camera frames |
| **ZMQ** | ZeroMQ - High-performance messaging library |

---

## Version Information

- **Fork Author**: twilsonco
- **Base Version**: openpilot v0.8.9 (Winter 2021)
- **Lateral Model**: 0.8.12 (last medium model)
- **Driver Monitoring Model**: 0.8.10
- **OS**: AGNOS4 (Comma Three)
- **Python**: 3.8
- **Branches**:
  - `tw-main`: Stable release
  - `tw-staging`: Active development (current)
  - `tw-dev`: Experimental

---

**Document End**

*This reference was generated by analyzing the codebase structure. For the most up-to-date information, refer to the source code and official documentation.*

*Last Updated: 2025-11-06*
