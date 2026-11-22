# Development log

## 2026-11-21

TX-to-RX loopback passed at 9600 and 115200 baud.

Added the tutorial d demo: left button sends HELLO, right sends ALARM. Message, debounce and long-press tests passed at both baud rates in XSim. Vivado 2019.1 synthesis passed, with no I/O pin or standard violations. Routed demo TX to JA pin 1 for Analog Discovery / WaveForms measurement. Next: build and demonstrate on the school board in Vivado 2025.2.

## 2026-11-19

Finished the RX logic and tests. Both 9600 and 115200 baud passed in XSim 2019.1, including false starts, bad stop bits, consecutive frames and reset recovery. ModelSim compiled the tests, but its simulation license was unavailable. Next: TX-to-RX loopback.

## 2026-11-18

Finished UART TX with configurable baud rate. ModelSim tests passed at 9600 and 115200 baud, including busy requests, consecutive frames and reset recovery. Still needs checking in Vivado 2025.2 and on the board.

Started RX with the interface and two-stage input synchronizer. Next: detect and confirm the start bit.

## 2026-11-16

Set up the Nexys A7-100T project and drafted the PCB interface. Pins and the authentication protocol are still undecided.
