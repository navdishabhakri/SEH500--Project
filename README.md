# SEH500--Project

🏥 Pain Level Communicator (PLC)

Course: SEH500 - Microprocessors and Computer Architecture
Platform: NXP FRDM-K66F (ARM Cortex-M4)
Language: C & GNU Assembly (Mixed Implementation)


📖 Project Overview
The Pain Level Communicator (PLC) is an embedded assistive technology device designed to bridge the communication gap between non-verbal patients (e.g., stroke, ALS, intubated) and healthcare providers.
Using a single-button interface, patients can quantify their pain on a scale of 1-5. The system provides immediate visual feedback via an RGB LED and transmits the data to a central Nurse Console via UART. The system features two-way communication, allowing nurses to send acknowledgment signals back to the patient device.

✨ Key Features
Single-Button Input: Accessible interface for patients with limited motor control.
Real-Time Feedback: RGB LED indicates pain severity (Green → Yellow → Red).

2-Way UART Communication:
Tx: Transmits pain levels and timestamps to the Nurse Console.
Rx: Receives commands ('A', 'M', 'D') to trigger specific feedback lights on the patient board.
Low-Level Assembly Drivers: LED control logic written in pure GNU Assembly for zero-latency Direct Register Access.
Data Logging: Tracks the last 10 pain events with system uptime timestamps.

🛠️ Hardware & Pin Mapping

| Component        | Hardware Label | Port/Pin | Function                          |
|------------------|----------------|----------|-----------------------------------|
| Patient Button   | SW2            | PTD11    | Input (Falling Edge Interrupt)    |
| Red LED          | RGB_RED        | PTC9     | Output (Assembly Controlled)      |
| Green LED        | RGB_GREEN      | PTE6     | Output (Assembly Controlled)      |
| Blue LED         | RGB_BLUE       | PTA11    | Output (Assembly Controlled)      |
| UART Console     | USB Debug      | UART0    | Serial Communication (115200 Baud)|


📂 Project Structure

source/Project.c: The main C application logic. Handles Interrupt Service Routines (GPIO/PIT), Circular Buffer history logging, and UART polling.

source/led_logic.s: The Assembly Driver Layer. Handles Direct Memory Access to GPIO registers (PDOR, PDDR, SCGC5) to control LED colors without SDK overhead.

⚙️ Setup & Installation

Prerequisites

IDE: MCUXpresso IDE (v11.x or later)
Hardware: NXP FRDM-K66F Development Board
Terminal: PuTTY, TeraTerm, or MCUXpresso Built-in Terminal


Note: This project uses a "Manual Clock Force" routine in main(). You do not need to configure clocks in the GUI tools; the code handles it automatically to prevent Bus Faults.

🖥️ Usage Guide

1. Patient Mode (Input)
Press SW2 to increment pain level.
1 Press: Level 1
...
5 Presses: Level 5
Stop pressing. After 1.5 seconds, the system locks the entry.

Visual Feedback: The LED will light up corresponding to the level:

🟢 Green: Level 1 (Mild)
🔵 Blue: Level 2
🟡 Yellow: Level 3
🟣 Purple: Level 4
🔴 Red: Level 5 (Severe)

2. Nurse Console (Terminal Commands)

Open your Serial Terminal (115200 baud, 8N1) to interact with the system.
| Command Key | Action          | Board Response | Meaning                               |
|-------------|------------------|----------------|----------------------------------------|
| A           | Acknowledge      | Steady White   | "Message Received."                    |
| M           | Medication       | Cyan Light     | "Meds are on the way."                 |
| D           | Doctor           | Steady White   | "Doctor summoned."                     |
| R           | Reset            | LED OFF        | System Reset / Patient Discharged.     |
| S           | Status Sheet     | Print Report   | Prints history log to terminal.        |

Print Report

Prints history log to terminal.
