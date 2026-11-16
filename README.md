# Authenticated Motion Detector

EDA234 FPGA project for the Nexys A7-100T (`xc7a100tcsg324-1`).

The FPGA communicates with an ESP32 authentication unit through a PCB-mounted HC-06 UART/Bluetooth module. The PCB also includes a motion sensor, LED, buzzer and optional OLED.

## Files

- `rtl/`: VHDL sources
- `tb/`: testbenches
- `constraints/`: pin and timing constraints
- `scripts/`: Vivado project scripts
- [FPGA-PCB interface](docs/interfaces/fpga-pcb.md)
- [Development log](CHANGELOG.md)

## Create the Vivado project

Run from the repository root:

```powershell
vivado -mode batch -source scripts/create_project.tcl
```

Output: `build/nexys_a7_100t/amd_fpga.xpr`.
For a fresh project without overwriting an existing one:

```powershell
vivado -mode batch -source scripts/create_project.tcl -tclargs build/rebuild
```

Source files are listed in `scripts/sources.tcl`. Generated files are excluded from version control.

## Status

Project creation checked in Vivado 2019.1. No RTL or testbenches yet.
The XDC template is disabled pending the pin map.
