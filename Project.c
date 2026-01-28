/* K66F Pain Level Communicator - C Main */
#include "board.h"
#include "peripherals.h"
#include "pin_mux.h"
#include "clock_config.h"
#include "fsl_debug_console.h"
#include "fsl_pit.h"
#include "fsl_uart.h"
#include "fsl_port.h"
#include "fsl_gpio.h"

// Define Hardware mapping for K66F
#define SW2_GPIO GPIOD
#define SW2_PIN 11U
#define SW2_IRQ PORTD_IRQn

// --- HISTORY SETTINGS ---
#define MAX_HISTORY 10

// External Assembly Functions
extern void asm_setup_gpio(void);
extern void asm_set_pain_led(int level);
extern void asm_nurse_ack(void);

// --- GLOBAL VARIABLES ---
volatile int press_count = 0;       // Counts clicks in current session
volatile int stored_pain_level = 0; // Stores the final result
volatile bool input_active = false;
volatile char rx_char = 0;

// History Data Structure
volatile int patient_history[MAX_HISTORY];
volatile int history_index = 0;

// 1. GPIO Interrupt Handler (Button Press)
void PORTD_IRQHandler(void) {
    GPIO_PortClearInterruptFlags(SW2_GPIO, 1U << SW2_PIN);

    press_count++;
    input_active = true;

    // Reset Timeout Window
    PIT_StopTimer(PIT, kPIT_Chnl_0);
    PIT_StartTimer(PIT, kPIT_Chnl_0);

    PRINTF("Button Pressed! Current Session Count: %d\r\n", press_count);
}

// 2. PIT Timer Interrupt (Timeout - user finished pressing)
void PIT0_IRQHandler(void) {
    PIT_ClearStatusFlags(PIT, kPIT_Chnl_0, kPIT_TimerFlag);
    PIT_StopTimer(PIT, kPIT_Chnl_0);

    if (input_active) {
        stored_pain_level = press_count;

        PRINTF("Input Complete. Final Pain Level: %d\r\n", stored_pain_level);

        // --- SAVE TO HISTORY LOG ---
        if (history_index < MAX_HISTORY) {
            patient_history[history_index] = stored_pain_level;
            history_index++;
        } else {
            // Array is full, shift everything left (FIFO) to make room
            for(int i=0; i < MAX_HISTORY-1; i++) {
                patient_history[i] = patient_history[i+1];
            }
            patient_history[MAX_HISTORY-1] = stored_pain_level;
        }
        // ---------------------------

        asm_set_pain_led(stored_pain_level);
        PRINTF("PAIN_LEVEL:%d\r\n", stored_pain_level);

        press_count = 0;
        input_active = false;
    }
}

// 3. Main Loop
int main(void) {
    BOARD_InitBootPins();
    BOARD_InitBootClocks();
    BOARD_InitBootPeripherals();
    BOARD_InitDebugConsole();

    /* * GenAI Citation: Gemini provided this Manual Clock Force routine to prevent
         * the Assembly driver from triggering a Hard Fault on startup.
    */

    CLOCK_EnableClock(kCLOCK_PortA);
    CLOCK_EnableClock(kCLOCK_PortC);
    CLOCK_EnableClock(kCLOCK_PortD);
    CLOCK_EnableClock(kCLOCK_PortE);

    asm_setup_gpio();

    /* * GenAI Citation: Gemini provided the manual configuration struct below
         * to enable the internal Pull-Up Resistor for stable button reads.
    */

    // Force Button Config
    port_pin_config_t sw2_setup = {
        kPORT_PullUp,
        kPORT_FastSlewRate,
        kPORT_PassiveFilterDisable,
        kPORT_OpenDrainDisable,
        kPORT_LowDriveStrength,
        kPORT_MuxAsGpio,
        kPORT_UnlockRegister
    };
    PORT_SetPinConfig(PORTD, SW2_PIN, &sw2_setup);

    gpio_pin_config_t sw2_gpio_config = {kGPIO_DigitalInput, 0};
    GPIO_PinInit(SW2_GPIO, SW2_PIN, &sw2_gpio_config);

    PORT_SetPinInterruptConfig(PORTD, SW2_PIN, kPORT_InterruptFallingEdge);
    EnableIRQ(SW2_IRQ);
    EnableIRQ(PIT0_IRQn);

    PRINTF("\r\n========================================\r\n");
    PRINTF("   Pain Level Communicator (PLC) v1.0   \r\n");
    PRINTF("========================================\r\n");
    PRINTF("COMMANDS:\r\n");
    PRINTF(" [A] - Acknowledge (White Light)\r\n");
    PRINTF(" [M] - Meds Sent (Cyan Light)\r\n");
    PRINTF(" [D] - Doctor Summoned (White Light)\r\n");
    PRINTF(" [S] - Generate Analysis Sheet\r\n");
    PRINTF(" [R] - Reset System & Clear History\r\n");
    PRINTF("========================================\r\n");

    while(1) {
        uint32_t flags = UART_GetStatusFlags((UART_Type*)BOARD_DEBUG_UART_BASEADDR);

        if (flags & kUART_RxDataRegFullFlag) {
            rx_char = GETCHAR();

            // --- COMMAND A: ACKNOWLEDGE ---
            if (rx_char == 'A' || rx_char == 'a') {
                PRINTF("[Nurse]: Message Received (ACK).\r\n");
                asm_nurse_ack();
            }

            // --- COMMAND M: MEDS ---
            else if (rx_char == 'M' || rx_char == 'm') {
                PRINTF("[Nurse]: Medication is on the way.\r\n");
                asm_set_pain_led(6);
            }

            // --- COMMAND D: DOCTOR ---
            else if (rx_char == 'D' || rx_char == 'd') {
                PRINTF("[Nurse]: DOCTOR SUMMONED.\r\n");
                asm_set_pain_led(7);
            }

            // --- COMMAND S: REPORT SHEET ---
            else if (rx_char == 'S' || rx_char == 's') {
                PRINTF("\r\n--- PATIENT HISTORY ANALYSIS ---\r\n");
                if (history_index == 0) {
                    PRINTF("No records found.\r\n");
                } else {
                    for(int i=0; i < history_index; i++) {
                        PRINTF("Event #%d: Pain Level %d\r\n", i+1, patient_history[i]);
                    }
                    PRINTF("--------------------------------\r\n");
                    PRINTF("Total Events Recorded: %d\r\n", history_index);
                }
                PRINTF("--------------------------------\r\n");
            }

            // --- COMMAND R: RESET ---
            else if (rx_char == 'R' || rx_char == 'r') {
                PRINTF("[Nurse]: System Reset. History Cleared.\r\n");
                asm_set_pain_led(0);
                press_count = 0;
                history_index = 0; // Clear the report
            }
        }
    }
    return 0;
}
