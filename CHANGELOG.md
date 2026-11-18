# Development log

## 2026-11-18

Finished UART TX with configurable baud rate. ModelSim tests passed at 9600 and 115200 baud, including busy requests, consecutive frames and reset recovery. Still needs checking in Vivado 2025.2 and on the board.

Started RX with the interface and two-stage input synchronizer. Next: detect and confirm the start bit.

## 2026-11-16

Set up the Nexys A7-100T project and drafted the PCB interface. Pins and the authentication protocol are still undecided.
