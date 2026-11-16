# TEMPLATE ONLY. Not enabled in scripts/sources.tcl.
# Confirm ports, physical connectors and PCB schematic before enabling constraints.
# Source: https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc
# Copy only the needed assignments from the official file and match real top ports.
# Clock port planned: clk_100mhz. Nominal period: 10.000 ns.
# FPGA package pin for clock: confirm against official master XDC before use.
# UART, motion, LED, buzzer and optional OLED pins: TBD with PCB team.
# Do not build a bitstream from an unconstrained design.
