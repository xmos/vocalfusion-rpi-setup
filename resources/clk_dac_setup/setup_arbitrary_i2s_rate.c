// Copyright (c) 2019-2025, XMOS Ltd, All rights reserved

#include "rpi_clk_common.h"

static int setupBCLK(unsigned source_clk_khz, unsigned lrclk_hz, int enable) {
  // BCLK = LRCLK * 64 (typical for I2S)
  const double bclk_per_lrclk = 64.0;
  unsigned bclk_hz = lrclk_hz * bclk_per_lrclk;
  
  // Calculate clock dividers
  int divI, divF;
  if (calculateClockDividers(source_clk_khz, bclk_hz, &divI, &divF) < 0) {
    return -1;
  }

  printf("Setting BCLK to %.3f kHz (LRCLK %.3f Hz) using PLLD (I=%d F=%d)\n",
         (float)source_clk_khz / (divI + (float)divF / 4096), 
         (float)lrclk_hz, divI, divF);

  // Stop the clock first
  clkReg[CLK_PCM_CTL] = CLK_PASSWD | CLK_CTL_KILL;

  // Wait for clock to stop
  // 10,000 iterations seems to take ~1s, though usually the clock will have
  // stopped on the first iteration.
  unsigned int max_wait_iters = 10000;
  unsigned int wait_iters = 0;
  while ((clkReg[CLK_PCM_CTL] & CLK_CTL_BUSY) && wait_iters < max_wait_iters) {
    usleep(10);
    wait_iters++;
  }

  if (wait_iters >= max_wait_iters) {
      fprintf(stderr, "Error: clock didn't stop after %d iterations (max: %d)\n", wait_iters, max_wait_iters);
      exit(1);
  }

  // Set the divider
  clkReg[CLK_PCM_DIV] = CLK_PASSWD | CLK_DIV_DIVI(divI) | CLK_DIV_DIVF(divF);
  usleep(10);

  // Configure clock source (PLLD) and MASH filter
  clkReg[CLK_PCM_CTL] =
      CLK_PASSWD | CLK_CTL_MASH(1) | CLK_CTL_SRC(CLK_CTL_SRC_PLLD);
  usleep(10);

  // Enable clock if requested
  if (enable) {
    clkReg[CLK_PCM_CTL] |= CLK_PASSWD | CLK_CTL_ENAB;
  }

  return 0;
}

int main(int argc, char *argv[argc + 1]) {
  unsigned hw_rev = getGpioHardwareRevision();
  unsigned source_clk_khz;
  double lrclk_hz;

  // Check for required LRCLK frequency argument
  if (argc <= 1) {
    fprintf(stderr, "Usage: %s <lrclk_frequency_hz>\n", argv[0]);
    fprintf(stderr, "Example: %s 48000\n", argv[0]);
    return EXIT_FAILURE;
  }

  lrclk_hz = atof(argv[1]);
  if (lrclk_hz < 8000) {
    fprintf(stderr, "Invalid LRCLK frequency: %.1f Hz (minimum 8000 Hz)\n", lrclk_hz);
    return EXIT_FAILURE;
  }

  printf("Requested LRCLK: %.1f Hz\n", lrclk_hz);

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

  // Set up BCLK for the requested LRCLK frequency
  if (setupBCLK(source_clk_khz, lrclk_hz, 1) < 0) {
    fprintf(stderr, "Error setting up BCLK\n");
    return EXIT_FAILURE;
  }

  printf("BCLK configured for PCM interface\n");

  return EXIT_SUCCESS;
}
