// Copyright (c) 2019-2023, XMOS Ltd, All rights reserved

/*
    Trimmed down version of the minimal_clk.c file present
    in http://abyz.co.uk/rpi/pigpio/code/minimal_clk.zip
 */

/*
   gcc -o setup_mclk_bclk.c
   sudo ./setup_mclk_bclk
*/

/*
   Set the general purpose clk GPCLK0 (gpio4) to 12.288 MHz,
   and PCM CLK to 3.072 MHz, using PLLD as source.
*/


#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <unistd.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>


static volatile uint32_t piPeriphBase = 0x20000000;

#define CLK_BASE   (piPeriphBase + 0x101000)
#define GPIO_BASE  (piPeriphBase + 0x200000)

#define CLK_LEN   0xA8
#define GPIO_LEN  0xB4

#define CLK_PASSWD  (0x5A<<24)

#define CLK_CTL_MASH(x)((x)<<9)
#define CLK_CTL_BUSY    (1 <<7)
#define CLK_CTL_KILL    (1 <<5)
#define CLK_CTL_ENAB    (1 <<4)
#define CLK_CTL_SRC(x) ((x)<<0)

#define CLK_SRCS 4

#define CLK_CTL_SRC_OSC  1  /* 19.2 MHz */
#define CLK_CTL_SRC_PLLC 5  /* 1000 MHz */
#define CLK_CTL_SRC_PLLD 6  /*  500 MHz for RPi 3, 750 MHz for RPi 4*/
#define CLK_CTL_SRC_HDMI 7  /*  216 MHz */

#define CLK_DIV_DIVI(x) ((x)<<12)
#define CLK_DIV_DIVF(x) ((x)<< 0)

#define CLK_GP0_CTL 28
#define CLK_GP0_DIV 29
#define CLK_GP1_CTL 30
#define CLK_GP1_DIV 31
#define CLK_GP2_CTL 32
#define CLK_GP2_DIV 33

#define CLK_PCM_CTL 38
#define CLK_PCM_DIV 39

#define CLK_PWM_CTL 40
#define CLK_PWM_DIV 41

/* Hardware revision codes */
#define HW_REVISION_RPI1_ZERO	0x00
#define HW_REVISION_RPI2      	0x01
#define HW_REVISION_RPI3 	0x02
#define HW_REVISION_RPI4 	0x03

static volatile uint32_t  *gpioReg = MAP_FAILED;
static volatile uint32_t  *clkReg  = MAP_FAILED;


/* gpio modes. */
#define PI_INPUT  0
#define PI_OUTPUT 1
#define PI_ALT0   4
#define PI_ALT1   5
#define PI_ALT2   6
#define PI_ALT3   7
#define PI_ALT4   3
#define PI_ALT5   2


void gpioSetMode(unsigned gpio, unsigned mode)
{
    int reg, shift;

    reg   =  gpio/10;
    shift = (gpio%10) * 3;

    gpioReg[reg] = (gpioReg[reg] & ~(7<<shift)) | (mode<<shift);
}


unsigned getGpioHardwareRevision(void)
{
    static unsigned rev = 0;

    FILE * filp;
    char buf[512];
    char term;
    int chars=4; /* number of chars in revision string */

    if (rev) return rev;

    uint32_t piModel = 0;

    filp = fopen ("/proc/cpuinfo", "r");

    if (filp != NULL)
    {
        while (fgets(buf, sizeof(buf), filp) != NULL)
        {
            if (!strncasecmp("revision\t:", buf, 10))
            {
                if (sscanf(buf+10, "%x%c", &rev, &term) == 2)
                {
                    if (term != '\n') rev = 0;
                }
            }
        }
        fclose(filp);
    } else {
        fprintf(stderr, "cannot open file %s", "/proc/cpuinfo");
        return -1;
    }
    unsigned hw_rev = (rev >> 12) & 0xF;
    return hw_rev;
}


static int initClock(int clock, int source, int divI, int divF, int mash, int enable)
{
    int ctl[] = {CLK_GP0_CTL, CLK_GP2_CTL, CLK_PCM_CTL};
    int div[] = {CLK_GP0_DIV, CLK_GP2_DIV, CLK_PCM_DIV};
    int src[CLK_SRCS] =
        {CLK_CTL_SRC_PLLD,
        CLK_CTL_SRC_OSC,
        CLK_CTL_SRC_HDMI,
        CLK_CTL_SRC_PLLC};

    int clkCtl, clkDiv, clkSrc;
    uint32_t setting;

    if ((clock  < 0) || (clock  > 2))    return -1;
    if ((source < 0) || (source > 3 ))   return -2;
    if ((divI   < 2) || (divI   > 4095)) return -3;
    if ((divF   < 0) || (divF   > 4095)) return -4;
    if ((mash   < 0) || (mash   > 3))    return -5;

    clkCtl = ctl[clock];
    clkDiv = div[clock];
    clkSrc = src[source];

    clkReg[clkCtl] = CLK_PASSWD | CLK_CTL_KILL;

    /* wait for clock to stop */
    while (clkReg[clkCtl] & CLK_CTL_BUSY)
    {
        usleep(10);
    }

    clkReg[clkDiv] =
        (CLK_PASSWD | CLK_DIV_DIVI(divI) | CLK_DIV_DIVF(divF));

    usleep(10);

    clkReg[clkCtl] =
        (CLK_PASSWD | CLK_CTL_MASH(mash) | CLK_CTL_SRC(clkSrc));

    usleep(10);

    if(enable)
    {
        clkReg[clkCtl] |= (CLK_PASSWD | CLK_CTL_ENAB);
    }

    return 0;
}


/* Map in registers. */
static uint32_t * initMapMem(int fd, uint32_t addr, uint32_t len)
{
    return (uint32_t *) mmap(0, len,
       PROT_READ|PROT_WRITE|PROT_EXEC,
       MAP_SHARED|MAP_LOCKED,
       fd, addr);
}


unsigned gpioInitialise(void)
{
    int fd = open("/dev/mem", O_RDWR | O_SYNC) ;
    if (fd < 0)
    {
        fprintf(stderr, "This program needs root privileges.  Try using sudo\n");
        return -1;
    }

    gpioReg  = initMapMem(fd, GPIO_BASE, GPIO_LEN);
    clkReg   = initMapMem(fd, CLK_BASE,  CLK_LEN);

    close(fd);

    if ((gpioReg == MAP_FAILED) ||
        (clkReg == MAP_FAILED))
    {
        fprintf(stderr, "Bad, mmap failed\n");
        return -1;
    }
    return 0;
}


int main(int argc, char *argv[])
{
    char *clocks[CLK_SRCS]={"PLLD", " OSC", "HDMI", "PLLC"};
    unsigned hw_rev = getGpioHardwareRevision(); 
    
    /* set peripherals address */
    switch (hw_rev)
    {

        case HW_REVISION_RPI2:   /* BCM2836 (Raspberry Pi 2)*/
        case HW_REVISION_RPI3:   /* BCM2837 (Raspberry Pi 3)*/
            printf("Raspberry Pi 2 / 3 detected\n");
            piPeriphBase = 0x3F000000;
            break;

        case HW_REVISION_RPI4:   /* BCM2711 (Raspberry Pi 4B)*/
            printf("Raspberry Pi 4 detected\n");
            piPeriphBase = 0xFE000000;
            break;

        default:
            fprintf(stderr, "unsupported hardware revision code (%x)", hw_rev);
            return 1;
            break;
    }


    if (gpioInitialise() < 0) return 1;

    unsigned source_clk_kHz = 500000;
    // Handle the case for RPi4B:
    // PLLD clock used as source is 750MHz
    if (hw_rev == HW_REVISION_RPI4) {
       source_clk_kHz = 750000;
    }

#ifdef MCLK
    int clk_index = 0;
    int clk_source = 0;
    int clk_mash = 1;

    // dividers used in the formula: output_clock = source_clock / (clk_i + clk_f/4096)
    // values obtained using "python3 compute_clock_dividers.py 500000 12288"
    int clk_i = 40;
    int clk_f = 2826;

    // Handle the case for RPi4B:
    // values obtained using "python3 compute_clock_dividers.py 750000 12288"
    if (hw_rev == HW_REVISION_RPI4) {
       clk_i = 61;
       clk_f = 144;
    }

    int clk_enable = 1;

    printf("MCLK at %.3fkHz: using %s (I=%-4d F=%-4d MASH=%d)\n",
            (float)(source_clk_kHz / (clk_i + (float) clk_f/4096)),
            clocks[clk_source], clk_i, clk_f, clk_mash);
#else
    int i2s_16000 = 0;
    if (argc > 1){
       if (!strcmp(argv[1], "16000")){
            i2s_16000 = 1; 
            printf("Using LRCLK of 16000Hz\n");
        }
        else{
            printf("unknown option %s\n", argv[1]);
        }
    }
    else{
        printf("Using LRCLK 48000Hz\n");
    }

    int clk_index = 2;
    int clk_source = 0;
    int clk_mash = 1;
    // values obtained using "python3 compute_clock_dividers.py 500000 12288"
    int clk_i = 162;
    int clk_f = 3112;
    // Handle the case for RPi4B
    if (hw_rev == HW_REVISION_RPI4) {
        // values obtained using "python3 compute_clock_dividers.py 750000 12288"
        clk_i = 244;
        clk_f = 576;
    }

    if(i2s_16000)
    {
        // values obtained using "python3 compute_clock_dividers.py 750000 12288"
        clk_i = 488;
        clk_f = 1144;
        // Handle the case for RPi4B
        if (hw_rev == HW_REVISION_RPI4) {
            // values obtained using "python3 compute_clock_dividers.py 750000 12288"
            clk_i = 732;
            clk_f = 1728;
        }
    }
    int clk_enable = 0;
    printf("BCLK at %.3fkHz: using %s (I=%-4d F=%-4d MASH=%d)\n",
            (float)(source_clk_kHz / (clk_i + (float) clk_f/4096)),
            clocks[clk_source], clk_i, clk_f, clk_mash);
#endif //MCLK

    if (initClock(clk_index, clk_source, clk_i, clk_f, clk_mash, clk_enable) < 0)
    {
      printf("Error initialising clock\n");
      exit(-1);
    }

#ifdef MCLK
    unsigned mclk_mode =  PI_ALT0; //set GPCLK0 mode to alternate functionality (clock)

    if (argc > 1){
        if (!strcmp(argv[1], "--disable")){
            mclk_mode = PI_INPUT; //set GPCLK0 mode to input pin (switch clock off)
            printf("Disabling MCLK output\n");
        }
        else{
            printf("unknown option %s\n", argv[1]);
        }
    }
    gpioSetMode(4, mclk_mode);
#endif //MCLK

    //leave the clocks running and exit
    return 0;

}
