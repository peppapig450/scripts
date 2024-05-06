#!/usr/bin/env python3
import argparse
from operator import itemgetter


def get_args():
    parser = argparse.ArgumentParser(
        prog="Sort package info",
        description="Sort information about Gentoo packages.",
    )

    sort_params = parser.add_argument_group(
        title="Sort Options", description="What parameter to use to sort the output:"
    )
    sort_field = sort_params.add_mutually_exclusive_group(required=True)
    sort_field.add_argument(
        "-s",
        "--size",
        dest="sort_by",
        action="store_const",
        const="size",
        help="Sort by package size",
    )
    sort_field.add_argument(
        "-n",
        "--non-files",
        dest="sort_by",
        action="store_const",
        const="nonfiles",
        help="Sort by package's non file count.",
    )
    sort_field.add_argument(
        "-f",
        "--files",
        dest="sort_by",
        action="store_const",
        const="files",
        help="Sort by package's file count",
    )
    sort_field.add_argument(
        "-u",
        "--unique-files",
        dest="sort_by",
        action="store_const",
        const="unique",
        help="Sort by package's unique file count",
    )

    sort_order_top = parser.add_argument_group(
        title="Sort Order",
        description="Whether to sort from largest to smallest or vice versa:",
    )
    sort_order = sort_order_top.add_mutually_exclusive_group(required=True)
    sort_order.add_argument(
        "-l", "--least", action="store_true", help="Sort from least to greatest"
    )
    sort_order.add_argument(
        "-g", "--greatest", action="store_true", help="Sort from greatest to least"
    )

    output_options = parser.add_argument_group(
        title="Output Options", description="Options that control the program's output"
    )
    output_options.add_argument(
        "--limit",
        dest="limit_display_to",
        type=int,
        default=0,
        help="Limit output to specified number of packages",
    )
    return parser.parse_args()


def sort_lines(options, package_info):
    sort_key_indices = {"files": 1, "unique": 2, "nonfiles": 3, "size": 4}
    sort_by = options.sort_by

    key_function = lambda sublist: int(sublist[sort_key_indices[sort_by]][0])

    sorted_packages = sorted(
        package_info,
        key=key_function,
    )

    if options.limit_display_to and not 0:
        sorted_packages = sorted_packages[0 : options.limit_display_to]

    # humanize_all_sizes(sorted_packages)
    return sorted_packages


def humanize_size(bytes):
    pass


def read_lines():
    with open("test.txt", "r", encoding="utf-8") as file:
        lines = []
        for line in file:
            fields = line.strip(",").split()
            package = fields[0]

            files = (fields[1], " files")

            if "unique" in line:
                unique_files = (fields[3].strip("()"), " unique files")
                non_files = (fields[5], " non-files")
                size = (fields[7], fields[8])
            else:
                non_files = (fields[3], " non-files")
                unique_files = (0, " unique files")
                size = (fields[5], fields[6])

            lines.append([package, files, unique_files, non_files, size])

        return lines


if __name__ == "__main__":
    options = get_args()
    lines = read_lines()

    sorted_d = sort_lines(options, lines)
    for sort in sorted_d:
        print(sort)
