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

UART TX and RX have self-checking tests at 9600 and 115200 baud. TX passed in ModelSim SE-64 2020.4; RX passed in XSim 2019.1.
Vivado 2025.2 validation, synthesis and board tests are pending.
The XDC template is disabled pending the pin map.

## Tutorial UART demo (option d)

Top: `uart_button_demo`. Board: Nexys A7-100T.
BTNL sends `HELLO\r\n`; BTNR sends `ALARM\r\n`; BTNC resets.
LED0 is on while a message is being sent.
A held button sends once. Requests while busy are ignored; left wins simultaneous requests.
These are demonstration messages, not an authentication protocol.

For a manual Vivado 2025.2 project:

1. Create an RTL project for `xc7a100tcsg324-1`.
2. Add `rtl/uart_tx.vhd`, `rtl/button_debounce.vhd`,
   `rtl/uart_message_tx.vhd` and `rtl/uart_button_demo.vhd`.
3. Set `uart_button_demo` as the design top. Add only
   `constraints/uart_button_demo.xdc` for this demo.
4. Run synthesis, implementation and bitstream generation, then program the board.
5. With power off, connect JA pin 1 (TX, FPGA pin C17) to Analog Discovery DIO0,
   and JA pin 5 (GND) to Analog Discovery GND. Leave the Pmod power pins unconnected.
   Connect the board and Analog Discovery to the PC over their USB cables.
6. In WaveForms Logic, add a UART decoder on DIO0: 9600 baud, 8 data bits,
   no parity, 1 stop bit, normal polarity (idle high), ASCII format.
   Use DIO0 as an input. Capture at 1 MHz or faster for at least 20 ms after
   the first falling-edge trigger; arm the capture before pressing a button.
7. Press BTNC once, then capture BTNL and BTNR separately. Confirm HELLO and ALARM.
   Each message ends with CR and LF. Each bit should last about 104.17 us.

This demo sends TX through JA, not the onboard USB-UART serial port.
The JA assignment is for this measurement only; the final PCB pin map is separate.
This setup checks external TX. Testing external RX requires a UART signal source.

The default button debounce time is 10 ms at 100 MHz.
For simulation, add `rtl/uart_rx.vhd` and `tb/tb_uart_button_demo.vhd`,
use VHDL-2008, and select `tb_uart_button_demo` as the simulation top.
The testbench uses a shorter debounce count and checks both baud rates.
Board operation and Vivado 2025.2 validation are still pending.
