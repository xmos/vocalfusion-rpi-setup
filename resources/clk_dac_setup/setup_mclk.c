// Copyright (c) 2019-2025, XMOS Ltd, All rights reserved

#include "rpi_clk_common.h"

static int setupMCLK(unsigned source_clk_khz, unsigned target_freq_hz,
                     int enable) {
  int divI, divF;

  // Calculate clock dividers
  if (calculateClockDividers(source_clk_khz, target_freq_hz, &divI, &divF) <
      0) {
    return -1;
  }

  printf("Setting MCLK to %.3f kHz using PLLD (I=%d F=%d)\n",
         (float)source_clk_khz / (divI + (float)divF / 4096), divI, divF);

  // Stop the clock first
  clkReg[CLK_GP0_CTL] = CLK_PASSWD | CLK_CTL_KILL;

  // Wait for clock to stop
  // 10,000 iterations seems to take ~1s, though usually the clock will have
  // stopped on the first iteration.
  unsigned int max_wait_iters = 10000;
  unsigned int wait_iters = 0;
  while ((clkReg[CLK_GP0_CTL] & CLK_CTL_BUSY) && wait_iters < max_wait_iters) {
    usleep(10);
    wait_iters++;
  }

  if (wait_iters >= max_wait_iters) {
      fprintf(stderr, "Error: clock didn't stop after %d iterations (max: %d)\n", wait_iters, max_wait_iters);
      exit(1);
  }

  // Set the divider
  clkReg[CLK_GP0_DIV] = CLK_PASSWD | CLK_DIV_DIVI(divI) | CLK_DIV_DIVF(divF);
  usleep(10);

  // Configure clock source (PLLD) and MASH filter
  clkReg[CLK_GP0_CTL] =
      CLK_PASSWD | CLK_CTL_MASH(1) | CLK_CTL_SRC(CLK_CTL_SRC_PLLD);
  usleep(10);

  // Enable clock if requested
  if (enable) {
    clkReg[CLK_GP0_CTL] |= CLK_PASSWD | CLK_CTL_ENAB;
  }

  return 0;
}

int main(int argc, char *argv[argc + 1]) {
  unsigned hw_rev = getGpioHardwareRevision();
  unsigned source_clk_khz;
  int disable_mode = 0;

  // Check for disable flag
  if (argc > 1 && !strcmp(argv[1], "--disable")) {
    disable_mode = 1;
    printf("Disabling MCLK output\n");
  }

  // Set peripheral base address based on Pi model
  switch (hw_rev) {
  case HW_REVISION_RPI2:
  case HW_REVISION_RPI3:
    printf("Raspberry Pi 2/3 detected\n");
    piPeriphBase = 0x3F000000;
    source_clk_khz = 500000; // 500 MHz PLLD
    break;

  case HW_REVISION_RPI4:
    printf("Raspberry Pi 4 detected\n");
    piPeriphBase = 0xFE000000;
    source_clk_khz = 750000; // 750 MHz PLLD
    break;

  default:
    fprintf(stderr, "Unsupported hardware revision code (0x%x)\n", hw_rev);
    return EXIT_FAILURE;
  }

  if (gpioInitialise() < 0) {
    return EXIT_FAILURE;
  }

  if (disable_mode) {
    // Set GPIO4 to input mode to disable clock output
    gpioSetMode(4, PI_INPUT);
    printf("MCLK disabled\n");
  } else {
    // Set up MCLK at 12.288 MHz
    if (setupMCLK(source_clk_khz, 12288000, 1) < 0) {
      fprintf(stderr, "Error setting up MCLK\n");
      return EXIT_FAILURE;
    }

    // Set GPIO4 to ALT0 mode (GPCLK0)
    gpioSetMode(4, PI_ALT0);
    printf("MCLK enabled on GPIO4 (pin 7)\n");
  }

  return EXIT_SUCCESS;
}
