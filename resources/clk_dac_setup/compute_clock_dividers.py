import argparse

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('source_clock_khz', nargs='?', default=750000,
                        help="Source clock frequency in kHz")

    parser.add_argument('output_clock_khz',
                        help="Output clock frequency in kHz")
    args = parser.parse_args()


    diff = 1000
    final_div_i = 0;
    final_div_f = 0;
    for div_i in range(1, 1000):
        for div_f in range(0, 4096):
            computed_output_clock_khz = int(args.source_clock_khz)*1000/(div_i + div_f/4096)/1000
            new_diff = abs(computed_output_clock_khz - int(args.output_clock_khz))
            if new_diff < diff:
                diff = new_diff
                final_div_i = div_i
                final_div_f = div_f
                final_output_clock_khz = computed_output_clock_khz
                if diff == 0:
                    break
    print(f"source clock: {args.source_clock_khz}kHz, computed output clock: {final_output_clock_khz:.3f}kHz, diff: {diff}")
    print(f"\tDIV_I {final_div_i}")
    print(f"\tDIV_F {final_div_f}")

