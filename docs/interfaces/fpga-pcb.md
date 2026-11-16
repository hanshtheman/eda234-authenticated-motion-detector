# FPGA-PCB interface

Status: draft.

## System

Nexys A7-100T <-> UART <-> HC-06 <-> Bluetooth <-> ESP32.

PCB peripherals: motion sensor, LED, buzzer and optional OLED.
Module part numbers and the PCB revision are pending.

## Signals

Directions are relative to the FPGA. Signal names are provisional.

| Signal | Direction | PCB endpoint | Package pin / connector | Pending |
| --- | --- | --- | --- | --- |
| uart_tx | out | HC-06 RXD | TBD | Logic levels |
| uart_rx | in | HC-06 TXD | TBD | Logic levels |
| motion_in | in | Sensor interface | TBD | Polarity and pulse width |
| alarm_led | out | LED driver | TBD | Polarity and drive circuit |
| buzzer_ctrl | out | Buzzer driver | TBD | Active/passive buzzer, PWM |
| oled_* | TBD | Optional OLED | TBD | Bus type and pull-ups |
| GND | reference | PCB GND | TBD | Ground connection |

Supply voltages, signal levels and driver circuits must be confirmed before wiring.
PCB UART and onboard USB-UART pin assignments must be documented separately.

## UART

| Parameter | Value |
| --- | --- |
| Baud rate | TBD |
| Format | TBD |
| Idle level | High |
| Flow control | TBD |
| Receive buffering | TBD |
| HC-06 configuration | TBD |

## Authentication protocol

Pending: message framing, fields, byte order, authentication decision, timeout, retries,
duplicate handling, disconnection behaviour and alarm state transitions.

The exact ESP32 model and Bluetooth compatibility with the HC-06 are unconfirmed.
