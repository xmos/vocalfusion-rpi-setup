import argparse

def compute_dividers(source_clock_khz, output_clock_khz):
    div_i = int(source_clock_khz / output_clock_khz)
    div_f = int(((source_clock_khz / output_clock_khz) - div_i) * 4096)

    final_output_clock_khz = float(source_clock_khz)*1000/(div_i + div_f/4096)/1000

    return [final_output_clock_khz, div_i, div_f]

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('source_clock_khz', type=int,
                        help="Source clock frequency in kHz")

    parser.add_argument('desired_mclock_khz', type=int,
                        help="Desired frequency of MCLK in kHz")

    parser.add_argument('--mclk_pdm_clk_divider', '-d', type=int, default=1, choices=[1, 2],
                        help="XCore divider from input master clock to 6.144MHz DDR PDM microphone clock")

    args = parser.parse_args()

    [mclk_khz, mclk_div_i, mclk_div_f] = compute_dividers(args.source_clock_khz, args.desired_mclock_khz)

    mclk_bclk_ratio = 4 * args.mclk_pdm_clk_divider

    # The MCLK must be an exact multiple of the BCLK to avoid glitches in the I2S audio
    desired_bclk_48khz = float(mclk_khz) / mclk_bclk_ratio
    [bclk_48khz, bclk_48khz_div_i, bclk_48khz_div_f] = compute_dividers(args.source_clock_khz, desired_bclk_48khz)

    desired_bclk_16khz = mclk_khz / (mclk_bclk_ratio * 3)
    [bclk_16khz, bclk_16khz_div_i, bclk_16khz_div_f] = compute_dividers(args.source_clock_khz, desired_bclk_16khz)


    print(f"Given source clock: {args.source_clock_khz}kHz the dividers are:")
    print(f"\tMCLK: freq {mclk_khz}kHz CLK_I {mclk_div_i} CLK_F {mclk_div_f}")
    print(f"\tBCLK at 48kHz: freq {bclk_48khz}kHz, ratio {mclk_khz/bclk_48khz}, CLK_I {bclk_48khz_div_i}, CLK_F {bclk_48khz_div_f}")
    print(f"\tBCLK at 16kHz: freq {bclk_16khz}kHz, ratio {mclk_khz/bclk_16khz}, CLK_I {bclk_16khz_div_i} CLK_F {bclk_16khz_div_f}")
    if int(args.desired_mclock_khz) != mclk_khz:
        print(f"Warning: perfect value for MCLK couldn't be found: expected {args.desired_mclock_khz}, found  {mclk_khz}\n")
    if desired_bclk_48khz != bclk_48khz:
        print(f"Warning: perfect value for BCLK at 48kHz couldn't be found: expected {desired_bclk_48khz}, found  {bclk_48khz}\n")
    if desired_bclk_16khz != bclk_16khz:
        print(f"Warning: perfect value for BCLK at 16kHz couldn't be found: expected {desired_bclk_16khz}, found  {bclk_16khz}")


