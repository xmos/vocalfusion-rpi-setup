// Copyright (c) 2019-2025, XMOS Ltd, All rights reserved

#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/mman.h>
#include <unistd.h>
#include "rpi_clk_common.h"

// Global variables
volatile uint32_t piPeriphBase = 0x20000000;
volatile uint32_t *gpioReg = MAP_FAILED;
volatile uint32_t *clkReg = MAP_FAILED;

void gpioSetMode(unsigned gpio, unsigned mode) {
  // https://www.raspberrypi.org/app/uploads/2012/02/BCM2835-ARM-Peripherals.pdf
  // Section 6.2
  // Each GPIO function select register controls 10 pins
  int reg = gpio / 10;
  // Each pin uses 3 bits for mode selection
  int shift = (gpio % 10) * 3;

  // Clear and set new mode on pin
  gpioReg[reg] = (gpioReg[reg] & ~(7 << shift)) | (mode << shift);
}

unsigned getGpioHardwareRevision(void) {
  static unsigned rev = 0;
  FILE *fp;
  char buf[512];
  char term;

  if (rev) {
    return rev;
  }

  fp = fopen("/proc/cpuinfo", "r");
  if (fp == NULL) {
    fprintf(stderr, "Cannot open /proc/cpuinfo\n");
    return -1;
  }

  while (fgets(buf, sizeof(buf), fp) != NULL) {
    // Look for a line like:
    // Revision    : c03114
    if (!strncasecmp("revision\t:", buf, 10)) {
      // Put the hex value into rev
      if (sscanf(buf + 10, "%x%c", &rev, &term) == 2) {
        // Make sure the terminator is a new line
        if (term != '\n') {
          rev = 0;
        }
      }
    }
  }
  fclose(fp);

  // The format of this is specified here:
  // https://github.com/raspberrypi/documentation/blob/develop/documentation/asciidoc/computers/raspberry-pi/revision-codes.adoc
  // We want to select the processor, though the revision may also work

  // Original rev is something like:
  // 0b110000000011000100010100
  // After shift:
  // 0b110000000011
  // After mask:
  // 0b11 (HW_REVISION_RPI4)
  return (rev >> 12) & 0xF;
}

static uint32_t *initMapMem(int fd, uint32_t addr, uint32_t len) {
  return (uint32_t *)mmap(0, len, PROT_READ | PROT_WRITE | PROT_EXEC,
                          MAP_SHARED | MAP_LOCKED, fd, addr);
}

int gpioInitialise(void) {
  int fd = open("/dev/mem", O_RDWR | O_SYNC);
  if (fd < 0) {
    fprintf(stderr, "This program needs root privileges. Try using sudo\n");
    return -1;
  }

  // Map both the GPIO and CLK registers
  gpioReg = initMapMem(fd, GPIO_BASE, GPIO_LEN);
  clkReg = initMapMem(fd, CLK_BASE, CLK_LEN);
  close(fd);

  if (gpioReg == MAP_FAILED || clkReg == MAP_FAILED) {
    fprintf(stderr, "Memory mapping failed\n");
    return -1;
  }

  return 0;
}

int calculateClockDividers(unsigned source_khz, unsigned target_hz, int *divI,
                           int *divF) {
  // Formula: output_clock = source_clock / (divI + divF / 4096)
  double divisor = (double)source_khz * 1000.0 / target_hz;
  *divI = (int)divisor;
  *divF = (int)((divisor - *divI) * 4096);

  // Validate divider values
  if (*divI < 2 || *divI > 4095) {
    fprintf(stderr, "Invalid integer divider: %d\n", *divI);
    return -1;
  }

  if (*divF < 0 || *divF > 4095) {
    fprintf(stderr, "Invalid fractional divider: %d\n", *divF);
    return -1;
  }

  return 0;
}
