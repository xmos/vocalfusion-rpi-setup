// Copyright (c) 2019-2025, XMOS Ltd, All rights reserved

#ifndef RPI_CLOCK_COMMON_H
#define RPI_CLOCK_COMMON_H

#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

// Base addresses for different Pi models
extern volatile uint32_t piPeriphBase;

#define CLK_BASE (piPeriphBase + 0x101000)
#define GPIO_BASE (piPeriphBase + 0x200000)

#define CLK_LEN 0xA8
#define GPIO_LEN 0xB4

// Clock control register bits
#define CLK_PASSWD (0x5A << 24)
#define CLK_CTL_MASH(x) ((x) << 9)
#define CLK_CTL_BUSY (1 << 7)
#define CLK_CTL_KILL (1 << 5)
#define CLK_CTL_ENAB (1 << 4)
#define CLK_CTL_SRC(x) ((x) << 0)

// Clock sources
#define CLK_CTL_SRC_OSC 1  /* 19.2 MHz */
#define CLK_CTL_SRC_PLLC 5 /* 1000 MHz */
#define CLK_CTL_SRC_PLLD 6 /* 500 MHz for RPi 3, 750 MHz for RPi 4*/
#define CLK_CTL_SRC_HDMI 7 /* 216 MHz */

// Clock divider macros
#define CLK_DIV_DIVI(x) ((x) << 12)
#define CLK_DIV_DIVF(x) ((x) << 0)

// GPCLK0 registers (GPIO4)
#define CLK_GP0_CTL 28
#define CLK_GP0_DIV 29

// PCM clock registers
#define CLK_PCM_CTL 38
#define CLK_PCM_DIV 39

// Hardware revision codes
#define HW_REVISION_RPI2 0x01
#define HW_REVISION_RPI3 0x02
#define HW_REVISION_RPI4 0x03

// GPIO modes
// https://www.raspberrypi.org/app/uploads/2012/02/BCM2835-ARM-Peripherals.pdf
// Table 6.2
#define PI_INPUT 0
#define PI_OUTPUT 1
#define PI_ALT0 4

extern volatile uint32_t *gpioReg;
extern volatile uint32_t *clkReg;

// Set GPIO pin `gpio` to `mode` (PI_INPUT, PI_OUTPUT, PI_ALT0)
void gpioSetMode(unsigned gpio, unsigned mode);

// Get hardware revision of RPi (e.g. HW_REVISION_RPI4)
unsigned getGpioHardwareRevision(void);

// Initialise GPIO and register mapping
int gpioInitialise(void);

// Calculate clock dividers divI and divF with given source clock frequency and target
// frequency
int calculateClockDividers(unsigned source_khz, unsigned target_hz, int *divI, int *divF);

#endif // RPI_CLOCK_COMMON_H
