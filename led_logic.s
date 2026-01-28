/* K66F Assembly Module - Pain Level Communicator */
/* Target: NXP FRDM-K66F */
/* Logic: Active Low LEDs (0=ON, 1=OFF) */

.syntax unified
.cpu cortex-m4
.thumb

/* ========================================================================= */
/* K66F REGISTER DEFINITIONS                          */
/* ========================================================================= */

/* * GenAI Citation:
 * Gemini was used to generate the Physical Memory Map definitions below
 * to allow Direct Register Access, bypassing the standard SDK drivers.
 */

/* SIM_SCGC5 (System Clock Gating Control Register 5) */
.equ SIM_SCGC5,      0x40048038
.equ PORTA_CLOCK,    (1<<9)   /* Port A for Blue LED */
.equ PORTC_CLOCK,    (1<<11)  /* Port C for Red LED */
.equ PORTE_CLOCK,    (1<<13)  /* Port E for Green LED */

/* PCR (Pin Control Registers) - Set MUX to Alt 1 (GPIO) */
.equ PTC9_PCR,       0x4004B024  /* Red LED Pin Control */
.equ PTE6_PCR,       0x4004D018  /* Green LED Pin Control */
.equ PTA11_PCR,      0x4004902C  /* Blue LED Pin Control */
.equ MUX_GPIO,       0x100       /* Mux setting for GPIO mode */

/* PDDR (Port Data Direction Registers) - Set bit to 1 for Output */
.equ GPIOC_PDDR,     0x400FF094
.equ GPIOE_PDDR,     0x400FF114
.equ GPIOA_PDDR,     0x400FF014

/* PDOR (Port Data Output Registers) - Write 0/1 to drive pin */
.equ GPIOC_PDOR,     0x400FF080
.equ GPIOE_PDOR,     0x400FF100
.equ GPIOA_PDOR,     0x400FF000

/* Pin Masks */
.equ PIN9_MASK,      (1<<9)   /* Red is Pin 9 */
.equ PIN6_MASK,      (1<<6)   /* Green is Pin 6 */
.equ PIN11_MASK,     (1<<11)  /* Blue is Pin 11 */

.text

/* ========================================================================= */
/* FUNCTION: asm_setup_gpio                                                  */
/* Purpose:  Enable clocks and configure pins as GPIO Outputs                */
/* ========================================================================= */
.global asm_setup_gpio
.type asm_setup_gpio, %function
asm_setup_gpio:
    PUSH {R0-R2, LR}

    /* 1. Enable Clocks for Ports A, C, E */
    LDR R0, =SIM_SCGC5
    LDR R1, [R0]
    LDR R2, =PORTA_CLOCK
    ORR R1, R1, R2
    LDR R2, =PORTC_CLOCK
    ORR R1, R1, R2
    LDR R2, =PORTE_CLOCK
    ORR R1, R1, R2
    STR R1, [R0]

    /* 2. Configure Pin Muxing (PCR) to GPIO Mode */
    LDR R1, =MUX_GPIO

    /* Red (PTC9) */
    LDR R0, =PTC9_PCR
    STR R1, [R0]

    /* Green (PTE6) */
    LDR R0, =PTE6_PCR
    STR R1, [R0]

    /* Blue (PTA11) */
    LDR R0, =PTA11_PCR
    STR R1, [R0]

    /* 3. Configure Data Direction (PDDR) to Output */

    /* Red (Port C, Pin 9) */
    LDR R0, =GPIOC_PDDR
    LDR R1, [R0]
    LDR R2, =PIN9_MASK
    ORR R1, R1, R2
    STR R1, [R0]

    /* Green (Port E, Pin 6) */
    LDR R0, =GPIOE_PDDR
    LDR R1, [R0]
    LDR R2, =PIN6_MASK
    ORR R1, R1, R2
    STR R1, [R0]

    /* Blue (Port A, Pin 11) */
    LDR R0, =GPIOA_PDDR
    LDR R1, [R0]
    LDR R2, =PIN11_MASK
    ORR R1, R1, R2
    STR R1, [R0]

    /* 4. Turn All LEDs OFF initially */
    BL turn_all_off

    POP {R0-R2, PC}


/* ========================================================================= */
/* FUNCTION: asm_set_pain_led                                                */
/* Purpose:  Set LED color based on Pain Level or Nurse Command              */
/* Input:    R0 (Integer)                                                    */
/* Map:      0=Off, 1=Green, 2=Blue, 3=Yellow, 4=Purple, 5=Red               */
/* 6=Cyan (Meds), 7=White (Doctor)                                 */
/* ========================================================================= */
.global asm_set_pain_led
.type asm_set_pain_led, %function
asm_set_pain_led:
    PUSH {LR}

    /* 1. Turn everything off first to ensure clean color mixing */
    PUSH {R0}
    BL turn_all_off
    POP {R0}

    /* 2. Compare Input R0 to determine color */
    CMP R0, #0
    BEQ done_led       /* 0: OFF */

    CMP R0, #1
    BEQ set_green      /* 1: Green */

    CMP R0, #2
    BEQ set_blue       /* 2: Blue */

    CMP R0, #3
    BEQ set_yellow     /* 3: Yellow */

    CMP R0, #4
    BEQ set_purple     /* 4: Purple */

    CMP R0, #5
    BEQ set_red        /* 5: Red */

    CMP R0, #6
    BEQ set_cyan       /* 6: Cyan (Meds) */

    CMP R0, #7
    BEQ set_white      /* 7: White (Doctor) */

    /* If > 7, default to Red */
    B set_red

/* --- Color Subroutines (Active Low: BIC = ON) --- */

set_green:
    LDR R1, =GPIOE_PDOR
    LDR R2, [R1]
    LDR R3, =PIN6_MASK
    BIC R2, R2, R3     /* Clear Bit 6 (Green ON) */
    STR R2, [R1]
    B done_led

set_blue:
    LDR R1, =GPIOA_PDOR
    LDR R2, [R1]
    LDR R3, =PIN11_MASK
    BIC R2, R2, R3     /* Clear Bit 11 (Blue ON) */
    STR R2, [R1]
    B done_led

set_red:
    LDR R1, =GPIOC_PDOR
    LDR R2, [R1]
    LDR R3, =PIN9_MASK
    BIC R2, R2, R3     /* Clear Bit 9 (Red ON) */
    STR R2, [R1]
    B done_led

set_yellow: /* Red + Green */
    /* Red ON */
    LDR R1, =GPIOC_PDOR
    LDR R2, [R1]
    LDR R3, =PIN9_MASK
    BIC R2, R2, R3
    STR R2, [R1]
    /* Green ON */
    LDR R1, =GPIOE_PDOR
    LDR R2, [R1]
    LDR R3, =PIN6_MASK
    BIC R2, R2, R3
    STR R2, [R1]
    B done_led

set_purple: /* Red + Blue */
    /* Red ON */
    LDR R1, =GPIOC_PDOR
    LDR R2, [R1]
    LDR R3, =PIN9_MASK
    BIC R2, R2, R3
    STR R2, [R1]
    /* Blue ON */
    LDR R1, =GPIOA_PDOR
    LDR R2, [R1]
    LDR R3, =PIN11_MASK
    BIC R2, R2, R3
    STR R2, [R1]
    B done_led

set_cyan: /* Green + Blue (Nurse: Meds) */
    /* Green ON */
    LDR R1, =GPIOE_PDOR
    LDR R2, [R1]
    LDR R3, =PIN6_MASK
    BIC R2, R2, R3
    STR R2, [R1]
    /* Blue ON */
    LDR R1, =GPIOA_PDOR
    LDR R2, [R1]
    LDR R3, =PIN11_MASK
    BIC R2, R2, R3
    STR R2, [R1]
    B done_led

set_white: /* Red + Green + Blue (Nurse: Doctor) */
    /* Red ON */
    LDR R1, =GPIOC_PDOR
    LDR R2, [R1]
    LDR R3, =PIN9_MASK
    BIC R2, R2, R3
    STR R2, [R1]
    /* Green ON */
    LDR R1, =GPIOE_PDOR
    LDR R2, [R1]
    LDR R3, =PIN6_MASK
    BIC R2, R2, R3
    STR R2, [R1]
    /* Blue ON */
    LDR R1, =GPIOA_PDOR
    LDR R2, [R1]
    LDR R3, =PIN11_MASK
    BIC R2, R2, R3
    STR R2, [R1]
    B done_led

done_led:
    POP {PC}


/* ========================================================================= */
/* FUNCTION: asm_nurse_ack                                                   */
/* Purpose:  Turn on WHITE LED (Steady) to indicate Acknowledgment           */
/* * GenAI Citation: I learned the syntax for the BIC (Bit Clear) 
     * instruction from Gemini to correctly drive Active-Low LEDs.
*/
/* ========================================================================= */
.global asm_nurse_ack
.type asm_nurse_ack, %function
asm_nurse_ack:
    PUSH {LR}

    /* Ensure LEDs are OFF first to clear previous color */
    BL turn_all_off

    /* Turn Red ON (Bit 9 Port C) */
    LDR R0, =GPIOC_PDOR
    LDR R1, [R0]
    LDR R2, =PIN9_MASK
    BIC R1, R1, R2
    STR R1, [R0]

    /* Turn Green ON (Bit 6 Port E) */
    LDR R0, =GPIOE_PDOR
    LDR R1, [R0]
    LDR R2, =PIN6_MASK
    BIC R1, R1, R2
    STR R1, [R0]

    /* Turn Blue ON (Bit 11 Port A) */
    LDR R0, =GPIOA_PDOR
    LDR R1, [R0]
    LDR R2, =PIN11_MASK
    BIC R1, R1, R2
    STR R1, [R0]

    /* We just return. The light stays ON (Steady White) */
    POP {PC}


/* ========================================================================= */
/* HELPER: turn_all_off                                                      */
/* Purpose: Set all LED pins High (OFF)                                      */
/* ========================================================================= */
turn_all_off:
    /* Red OFF (Port C) */
    LDR R0, =GPIOC_PDOR
    LDR R1, [R0]
    LDR R2, =PIN9_MASK
    ORR R1, R1, R2
    STR R1, [R0]

    /* Green OFF (Port E) */
    LDR R0, =GPIOE_PDOR
    LDR R1, [R0]
    LDR R2, =PIN6_MASK
    ORR R1, R1, R2
    STR R1, [R0]

    /* Blue OFF (Port A) */
    LDR R0, =GPIOA_PDOR
    LDR R1, [R0]
    LDR R2, =PIN11_MASK
    ORR R1, R1, R2
    STR R1, [R0]

    BX LR

/* ========================================================================= */
/* HELPER: simple_delay                                                      */
/* Purpose: Burn CPU cycles for a visible delay                              */
/* ========================================================================= */
simple_delay:
    PUSH {R0}
    LDR R0, =0x200000   /* Adjust this value for speed */
delay_loop:
    SUBS R0, R0, #1
    BNE delay_loop
    POP {R0}
    BX LR
