#!/usr/bin/env python
"""
A script to produce tsv output from CNVpytor using the python interface

Example usage:
    python script.py --bins 1000 \\
                     --input sample1.bam \\
                     --prefix sample1 \\
                     --filter '{"Q0_range": [-1, 0.5], "p_range": [0, 0.0001], "p_N": [0, 0.5], "size_range": [50000, "inf"], "dG_range": [100000, "inf"]}' # noqa
"""
import argparse
import os
import csv
import logging
import cnvpytor

logger = logging.getLogger(__name__)

logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s %(name)s %(levelname)s %(message)s')


def process_files(bam_list: list,
                  bin_size_list: list,
                  prefix: str,
                  min_cnv_depth_dup: float = 0.,
                  max_cnv_depth_del: float = 100.,
                  max_cores: int = 1) -> None:
    """
    Processes files with given parameters.

    :param bam_list: List of input files.
    :type bam_list: list
    :param bin_size_list: List of bin sizes.
    :type bin_size_list: list
    :param prefix: Prefix for the output file.
    :type prefix: str
    :param min_cnv_depth_dup: Minimum CNV depth to call a duplication.
        Defaults to 0, which is no filter.
    :type min_cnv_depth_dup: float
    :param max_cnv_depth_del: Minimum CNV depth.
        Defaults to 1, which is no filter.
    :type min_cnv_depth_del: float
    :param max_cores: Maximum number of cores to use. Defaults to 1.
    :type max_cores: int

    :raises TypeError: if input parameters are not of the correct type.
    :raises FileExistsError: If bam_list contains files that do not exist or
        do not have the extension .bam.
    """
    # input checking
    if not isinstance(bam_list, list):
        raise TypeError("File list must be a list.")
    if not isinstance(bin_size_list, list):
        raise TypeError("bin_size_list must be a list.")
    if not isinstance(prefix, str):
        raise TypeError("Prefix must be a string.")
    if not isinstance(min_cnv_depth_dup, float) or min_cnv_depth_dup < 0:
        raise TypeError("Minimum CNV depth must be a positive float.")
    if not isinstance(max_cnv_depth_del, float) or max_cnv_depth_del < 0:
        raise TypeError("Minimum CNV depth must be a positive float.")
    if not isinstance(max_cores, int):
        raise TypeError("Maximum cores must be an integer.")
    for file in bam_list:
        if not os.path.exists(file) and not os.path.islink(file):
            raise FileExistsError(f"File {file} not found.")
        if not os.path.splitext(file)[1] == ".bam":
            raise ValueError(f"File {file} is not a .bam file.")

    pytor_file = f"{prefix}.pytor"
    logger.info('Creating pytor file %s', pytor_file)
    app = cnvpytor.Root(pytor_file,
                        create=True,
                        max_cores=max_cores)

    logger.info('Calculating read depth over all chromosomes')
    app.rd(bam_list)
    app.calculate_histograms(bin_size_list)
    app.partition(bin_size_list)
    calls = app.call(bin_size_list)

    for bin_size, call_list in calls.items():
        # Filter the list based on the condition for column index 5 (assuming
        # call_list contains lists)
        if min_cnv_depth_dup > 0 or max_cnv_depth_del < 100:
            filtered_call_list = [item for item in call_list
                                  if (item[5] > min_cnv_depth_dup
                                      and item[0] == 'duplication')
                                  or (item[5] < max_cnv_depth_del
                                      and item[0] == 'deletion')
                                  or item[0] not in ['deletion',
                                                     'duplication']]
            filename = prefix + '_' + str(bin_size) + '_filtered'
        else:
            filtered_call_list = call_list
            filename = prefix + '_' + str(bin_size)

        logger.info('Writing cnv calls to %s.csv', filename)

        # Assuming all dictionaries in filtered_call_list have the same keys
        # Sample column headers, replace these with the actual headers
        column_headers = ["type", "chr", "start", "end",
                          "length", "norm_depth",
                          "eval1", "eval2", "eval3", "eval4",
                          "q0", "pN", "dG"]
        with open(filename + ".csv",
                  'w',
                  newline='',
                  encoding='utf-8') as output_file:
            csv_writer = csv.writer(output_file)
            # Write the header
            csv_writer.writerow(column_headers)
            # Write the rows
            csv_writer.writerows(filtered_call_list)


def main():
    """main method for script"""
    parser = argparse.ArgumentParser(description='Use CNVpytor to call CNVs '
                                     'on a set of bam files over a give set '
                                     'of bin sizes. Optionally, filter the '
                                     'result based on normalized depth')
    parser.add_argument('--bams', required=True, nargs='+', type=str,
                        help='Input files as space-separated string.')
    parser.add_argument('--bins', required=True, nargs='+', type=int,
                        help='Bin sizes as space-separated integers.')
    parser.add_argument('--min_cnv_depth_dup', default=0., type=float,
                        help='Minimum CNV depth for filtering. '
                        'The default value of 0 means no filtering '
                        'based on CNV depth for duplications')
    parser.add_argument('--max_cnv_depth_del', default=100., type=float,
                        help='Maximum CNV depth for filtering. '
                        'The default value of 100 means no filtering '
                        'based on CNV depth for deletions.')
    parser.add_argument('--prefix', required=True, type=str,
                        help='Prefix for output files.')
    parser.add_argument('--max_cores', default='1', type=int,
                        help='Maximum number of cores to use.')

    args = parser.parse_args()

    process_files(args.bams,
                  args.bins,
                  args.prefix,
                  args.min_cnv_depth_dup,
                  args.max_cnv_depth_del,
                  args.max_cores)


if __name__ == "__main__":
    main()
