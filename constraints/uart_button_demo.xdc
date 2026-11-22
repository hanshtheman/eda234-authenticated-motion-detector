# Nexys A7-100T: standalone Pmod UART button demo.
# Use this file only with uart_button_demo as the top.
# Source: https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports clk_100mhz]
create_clock -name sys_clk -period 10.000 [get_ports clk_100mhz]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports btn_center]
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVCMOS33} [get_ports btn_left]
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVCMOS33} [get_ports btn_right]
# JA pin 1 -> Analog Discovery DIO0; connect board GND to instrument GND.
# This demo pin assignment is independent of the final PCB pin map.
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVCMOS33} [get_ports uart_tx]
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports led_busy]
