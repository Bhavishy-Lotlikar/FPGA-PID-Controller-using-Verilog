# PID Controller Design using Verilog HDL on FPGA

## Overview

This project implements a digital PID (Proportional–Integral–Derivative) controller using Verilog HDL in Vivado and deploys it on FPGA hardware. The system performs real-time PID computation, transmits controller data to a PC using UART, and visualizes the system response through a Python GUI.

The project integrates FPGA-based digital design, UART communication, and software visualization into a complete control-system workflow.

---

## Features

- Digital PID controller implemented in Verilog HDL
- FPGA deployment using Vivado
- Real-time PID computation
- UART communication between FPGA and PC
- Python GUI for live plotting and monitoring
- Testbench simulation and waveform verification
- Modular RTL design approach
- Hardware implementation and testing

---

## System Architecture

```text
FPGA PID Controller
        ↓
UART Transmission
        ↓
PC Serial Port
        ↓
Python GUI
        ↓
Real-Time Graph Visualization
```

UART data transmission format:

```text
SP=<SetPoint>,PO=<ProcessOutput>,CT=<ControlOutput>
```

Example:

```text
SP=120,PO=98,CT=74
```

---

## File Structure

```text
PID-Controller-Verilog/
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
├── simulation/
│   └── top_tb.vcd
│
├── Python_GUI/
│   └── pid_gui.py
│
├── requirements.txt
└── .gitignore
```

---

## Technologies Used

- Verilog HDL
- Vivado
- FPGA
- UART Communication
- Python
- Tkinter
- Matplotlib
- PySerial

---

## Installation

Clone the repository:

```bash
git clone <your-repository-link>
cd PID-Controller-Verilog
```

Install required packages:

```bash
pip install -r requirements.txt
```

Run Python GUI:

```bash
python pid_gui.py
```

---

## Simulation and Testing

The design was verified through:

- RTL simulation
- Testbench verification
- UART communication testing
- FPGA hardware testing
- Real-time GUI monitoring

---

## Future Improvements

- PID parameter tuning directly from GUI
- CSV data logging
- Adjustable sampling rates
- Closed-loop sensor integration
- Advanced response analysis tools

---

## Requirements

```txt
matplotlib>=3.7.0
pyserial>=3.5
tk
```

---

## Author

**Bhavishy**  
Electronics and Telecommunication Engineering (EXTC)
