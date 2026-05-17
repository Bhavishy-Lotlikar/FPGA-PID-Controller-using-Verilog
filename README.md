# FPGA PID Controller using Verilog HDL with UART Telemetry and Python GUI

Digital implementation of a **PID (Proportional–Integral–Derivative) controller** on an **EDGE Artix-7 FPGA (xc7a35tftg256-1)** using Verilog HDL. The project performs real-time PID control, simulates an internal plant model directly on FPGA hardware, streams live telemetry through UART, and visualizes system response using a Python GUI.

This project combines FPGA-based digital design, closed-loop control, UART communication, and software visualization into a complete hardware-software workflow.

---

## Hardware Implementation

<img width="1600" height="1200" alt="image" src="https://github.com/user-attachments/assets/5c90e8d6-a842-41c1-8528-56e41880f241" />

FPGA PID controller running on the EDGE Artix-7 board.

---

## Python GUI Output

<img width="1600" height="841" alt="WhatsApp Image 2026-05-06 at 11 18 18 AM" src="https://github.com/user-attachments/assets/ff708ac4-dd34-481b-bb6c-d17e1990194a" />

Real-time UART telemetry visualization.

---

## RTL Simulation

<img width="1582" height="813" alt="WhatsApp Image 2026-05-06 at 12 32 40 AM" src="https://github.com/user-attachments/assets/76c18d38-9b75-4663-990b-98eb5c2ef091" />

PID controller simulation output.

---

## Features

- PID controller implemented in Verilog HDL
- FPGA implementation using EDGE Artix-7 board
- Internal first-order plant model simulation
- Push-button based setpoint control
- Real-time PID gain tuning using switches
- Disturbance injection using hardware switches
- UART telemetry transmission
- Python GUI for real-time plotting and monitoring
- LED bar graph for control effort visualization
- 7-segment display output
- RTL simulation and hardware verification

---

## System Architecture

```text
Push Buttons
     ↓
Setpoint Register
     ↓
PID Controller
     ↓
Control Signal
     ↓
Internal Plant Model
     ↓
Plant Output
     ↓
UART Transmission
     ↓
USB Serial Interface
     ↓
Python GUI
     ↓
Real-Time Graph Visualization
```

---

## PID Equation

```text
Control Signal =
(Kp × Error)
+ (Ki × Integral(Error))
+ (Kd × Derivative(Error))
```

Plant model:

```text
plant_out = plant_out + ((control_signal - plant_out)>>3)
```

The plant behaves as a first-order lag system similar to motors and thermal systems.

---

## Hardware Controls

### Push Buttons

| Button | Function |
|----------|----------|
| Center | Reset system |
| Top | Setpoint +10 |
| Bottom | Setpoint −10 |
| Right | Setpoint +1 |
| Left | Setpoint −1 |

---

### Disturbance Injection

Switches:

```text
SW[7:0]
```

Examples:

- All OFF → No disturbance
- SW6 ON → Disturbance = 64
- All ON → Maximum disturbance

---

### PID Gain Tuning

Gain tuning switches:

```text
SW[15:8]
```

Recommended configuration:

| Parameter | Value |
|------------|-------|
| Kp | 4 |
| Ki | 1 |
| Kd | 2 |

Binary:

```text
1001 0011 0000 0000
```

Hex:

```text
0x9300
```

---

## UART Data Format

Telemetry transmitted from FPGA:

```text
SP=<SetPoint>,PO=<PlantOutput>,CT=<ControlSignal>
```

Example:

```text
SP=110,PO=98,CT=120
```

Where:

- SP → Setpoint
- PO → Plant output
- CT → PID control effort

UART Configuration:

```text
57600 baud
8 data bits
No parity
1 stop bit (8N1)
```

---

## File Structure

```text
FPGA-PID-Controller-using-Verilog/
│
├── src/
│   ├── pid_controller.v
│   ├── uart_tx.v
│   ├── seg7_driver.v
│   ├── btn_debounce.v
│   └── top.v
│
├── constraints/
│   └── pid_controller.xdc
│
├── testbench/
│   └── top_tb.v
│
├── Python_GUI/
│   └── pid_gui.py
│
├── requirements.txt
└── README.md
```

---

## Running the Project

### FPGA Setup

1. Open Vivado and create a new project.
2. Add all Verilog source files from the `src/` folder.
3. Add the constraint file:

```text
pid_controller.xdc
```

4. Set:

```text
top.v
```

as the top module.

5. Run:

- Synthesis
- Implementation
- Generate Bitstream

6. Open Hardware Manager:

```text
Open Target
→ Auto Connect
→ Program Device
```

After programming, the FPGA starts transmitting telemetry through UART.

---

### Python GUI Setup

Install required packages:

```bash
pip install -r requirements.txt
```

Launch GUI:

```bash
python pid_gui.py
```

---

### Connect FPGA to GUI

1. Connect FPGA board to PC through USB.

2. Open:

```text
Device Manager → Ports (COM & LPT)
```

3. Locate:

```text
USB Serial Port (COMX)
```

Example:

```text
COM5
```

4. Open the GUI.

5. Select the detected COM port.

6. Select baud rate:

```text
57600
```

7. Press:

```text
Refresh Ports
```

if required.

8. Click:

```text
Start
```

The GUI begins receiving data and displays real-time plots for:

- Set Point (SP)
- Plant Output (PO)
- Control Output (CT)

---

## Simulation Verification

Verified using:

- RTL simulation
- Testbench verification
- UART communication testing
- Hardware implementation
- Real-time GUI monitoring

Tested scenarios:

- Setpoint changes
- Disturbance injection
- Disturbance recovery
- Gain tuning
- Closed-loop response behavior

---

## Python Requirements

```txt
matplotlib>=3.7.0
pyserial>=3.5
tk
```

Install:

```bash
pip install -r requirements.txt
```

---

## Future Improvements

- GUI-based PID gain tuning
- CSV data logging
- External sensor feedback
- Advanced graph analysis
- PID auto-tuning

---

## Author

Bhavishy  
Electronics and Telecommunication Engineering (EXTC)

FPGA | Verilog | Digital Design | Embedded Systems
