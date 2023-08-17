#!/usr/bin/env python3
"""
A script for processing and filtering files using CNVpytor. This script
accepts a range of parameters for filtering genomic regions based on criteria
such as CNV depth, size range, etc., and exports the filtered results.

Example usage:
    python script.py --bins "1000"
                     --input "file1.pytor file2.pytor"
                     --prefix "output"
                     --output-suffix "tsv"
                     --filter '{"Q0_range": [-1, 0.5], "p_range": [0, 0.0001], "p_N": [0, 0.5], "size_range": [50000, "inf"], "dG_range": [100000, "inf"]}' # noqa
"""
import argparse
import cnvpytor
import json
import os


def parse_filter_str(filter_str):
    """
    Parses the filter string into a dictionary and replaces any "inf" with
      python inf.

    Args:
        filter_str (str): JSON-like string representation of the cnvpytor
          filter criteria.

    Raises:
        ValueError: If the input string is not a valid JSON object or if any
          of the expected keys or values are missing.

    Returns:
        dict: A filter dictionary that may be passed the cnvpytor view params

    Example:
        >>> parse_filter_str('{"size_range": [50000, "inf"]}')
        {'size_range': [50000, inf]}
    """
    # if filter_str is empty, return empty dict
    if not filter_str:
        return {}
    # else, try to parse the string
    try:
        filter_dict = json.loads(filter_str)
    except json.JSONDecodeError as exc:
        raise ValueError("Input string is not a valid JSON object.") from exc

    for key, value in filter_dict.items():
        if not isinstance(value, list) or not \
                all(isinstance(v, (int, float, str)) for v in value):
            raise ValueError(f"Invalid value for key {key}. "
                             f"Expected a list of numbers or 'inf'.")

        filter_dict[key] = [float('inf') if v == "inf" else v for v in value]

    return filter_dict


def process_files(file_list,
                  binsizes,
                  filter_str,
                  prefix,
                  output_suffix,
                  min_cnv_depth):
    """
    Processes files with given parameters.

    Args:
        file_list (list): List of input files.
        binsizes (list): List of bin sizes.
        filter_str (str): JSON-like string representation of filter criteria.
        prefix (str): Prefix for the output file.
        output_suffix (str): Suffix for the output file.
        min_cnv_depth (int): Minimum CNV depth.

    Raises:
        ValueError: If there are issues with filter string parsing or
          other parameters.
    """
    # Check if files exist
    for file in file_list:
        if not os.path.exists(file) or not os.path.islink(file):
            raise FileExistsError(f"File {file} not found.")

    filter_dict = parse_filter_str(filter_str)

    for binsize in binsizes:
        try:
            app = cnvpytor.Viewer(file_list, params=filter_dict)
            outputfile = "{}_{}.{}".format(
                prefix, binsize.strip(), output_suffix)
            app.print_filename = outputfile
            app.bin_size = int(binsize)
            app.print_calls_file()

            # Post-process the file to filter regions based on normalized depth
            filtered_output = "{}_{}_depthfiltered.{}".format(
                prefix, binsize.strip(), output_suffix)
            with open(outputfile, 'r', encoding='UTF-8') as infile, \
                    open(filtered_output, 'w', encoding='UTF-8') as outfile:
                for line in infile:
                    columns = line.strip().split('\t')
                    if float(columns[7]) > int(min_cnv_depth):
                        outfile.write(line)
        except Exception as exc:
            print(f"An error occurred while "
                  f"processing bin size {binsize}: {exc}")


def main():
    """main method for script"""
    parser = argparse.ArgumentParser(description='Process and filter files.')
    parser.add_argument('--bins', required=True,
                        help='Bins sizes as space-separated string.')
    parser.add_argument('--input', required=True,
                        help='Input files as space-separated string.')
    parser.add_argument('--filter', default='',
                        help='Filter string in JSON format.')
    parser.add_argument('--prefix', required=True,
                        help='Prefix for output files.')
    parser.add_argument('--output-suffix', required=True,
                        help='Suffix for output files.')
    parser.add_argument('--min-cnv-depth', default='0',
                        help='Minimum CNV depth for filtering.')

    args = parser.parse_args()

    pytor_input_list = args.input.split(' ')

    bin_list = args.bins.split(' ')

    process_files(pytor_input_list, bin_list, args.filter, args.prefix,
                  args.output_suffix, args.min_cnv_depth)


if __name__ == "__main__":
    main()
