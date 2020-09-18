import argparse

def compute_dividers(source_clock_khz, output_clock_khz):
    diff = 1000
    final_div_i = 0;
    final_div_f = 0;
    final_output_clock_khz = 0
    for div_i in range(1, 2000):
        for div_f in range(0, 4096):
            computed_output_clock_khz = float(source_clock_khz)*1000/(div_i + div_f/4096)/1000
            new_diff = abs(computed_output_clock_khz - float(output_clock_khz))
            # search for the minimum difference between the desired frequency and the one achievable with the dividers
            if new_diff < diff:
                diff = new_diff
                final_div_i = div_i
                final_div_f = div_f
                final_output_clock_khz = computed_output_clock_khz
                if diff == 0:
                    break
    return [final_output_clock_khz, final_div_i, final_div_f]

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('source_clock_khz',
                        help="Source clock frequency in kHz")

    parser.add_argument('desired_mclock_khz',
                        help="Desired frequency of MCLK in kHz")

    args = parser.parse_args()

    [mclk_khz, mclk_div_i, mclk_div_f] = compute_dividers(args.source_clock_khz, args.desired_mclock_khz)

    # The MCLK must be an exact multiple of the BCLK to avoid glitches in the I2S audio
    desired_bclk_48khz = float(mclk_khz) / 8
    [bclk_48khz, bclk_48khz_div_i, bclk_48khz_div_f] = compute_dividers(args.source_clock_khz, desired_bclk_48khz)

    desired_bclk_16khz = mclk_khz / 24
    [bclk_16khz, bclk_16khz_div_i, bclk_16khz_div_f] = compute_dividers(args.source_clock_khz, desired_bclk_16khz)


    print(f"Given source clock: {args.source_clock_khz}kHz the dividers are:")
    print(f"\tMCLK: freq {mclk_khz}kHz CLK_I {mclk_div_i} CLK_F {mclk_div_f}")
    print(f"\tBCLK at 48kHz: freq {bclk_48khz}kHz, ratio {mclk_khz/bclk_48khz}, CLK_I {bclk_48khz_div_i}, CLK_F {bclk_48khz_div_f}")
    print(f"\tBCLK at 16kHz: freq {bclk_16khz}kHz, ratio {mclk_khz/bclk_16khz}, CLK_I {bclk_16khz_div_i} CLK_F {bclk_16khz_div_f}")
    if int(args.desired_mclock_khz) != mclk_khz:
        print(f"Warning: perfect value for MCLK couldn't be found: expected {args.desired_mclock_khz}, found  {mclk_khz}\n")
    if desired_bclk_48khz != bclk_48khz:
        print(f"Warning: perfect value for BCLK at 48kHz couldn't be found: expected {desired_bclk_48khz}, found  {desired_bclk_48khz}\n")
    if desired_bclk_16khz != bclk_16khz:
        print(f"Warning: perfect value for BCLK at 16kHz couldn't be found: expected {desired_bclk_16khz}, found  {desired_bclk_16khz}")


