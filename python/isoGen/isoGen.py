##
# @file         isoGen.py
# @brief        A script to generate cloud-init seed ISO images (CIDATA).
# @details      This script automates the creation of a `seed.iso` file used to
#               provision cloud-init instances. It packages `user-data` and `meta-data` files
#               into an ISO 9660 filesystem with Joliet and Rock Ridge extensions.
#
#               The script supports flexible inputs: it accepts command-line parameters,
#               falls back to an interactive wizard if arguments are missing, and allows
#               the user to quickly approve default path selections.
#
# @author       Lior Y. Benjamin
# @date         June 2026
# @note         Requires administrative or standard user permissions depending on the destination directory.
#
# @section      dependencies Dependencies
#               - Python 3.x
#               - `pycdlib` library (Install via: `pip install pycdlib`)
#               - `pathlib`, `argparse`, and `sys` (Standard Python libraries)
#
# @section      usage Usage Examples
# @code
# # 1. Fully automated via CLI arguments:
# python isoGen.py -u /path/to/user-data -m /path/to/meta-data
#
# # 2. Partially automated (missing fields fall back to defaults):
# python isoGen.py -u /custom/user-data
#
# # 3. Interactive wizard mode:
# python isoGen.py
# @endcode
#

import os
import sys
import subprocess
import argparse
from pathlib import Path

# Get the absolute path of the parent directory ('python/')
current_directory = os.path.dirname(os.path.abspath(__file__))
parent_directory = os.path.dirname(current_directory)

# Add the parent directory to sys.path if it isn't already there
if parent_directory not in sys.path:
    sys.path.insert(0, parent_directory)

from infra.packages_handler import import_or_install

import_or_install("pycdlib")


## Base directory of the executing script.
BASE_DIR = Path(__file__).resolve().parent

## Default path to the cloud-init user-data file.
DEFAULT_USER_DATA = BASE_DIR / "user-data"

## Default path to the cloud-init meta-data file.
DEFAULT_META_DATA = BASE_DIR / "meta-data"

## Output path where the generated ISO file will be saved.
OUT_ISO = BASE_DIR / "seed.iso"

def get_input_paths():
    """
    @brief      Parses command-line arguments or falls back to interactive user prompts.
    @details    Evaluates if the user provided inputs via CLI switches (`-u` / `--user-data`
                and `-m` / `--meta-data`). If no arguments are provided, it prompts
                the user interactively in the terminal, allowing them to press [Enter]
                to accept the pre-defined default paths.

    @return     tuple A pair of Path objects: (user_data_path, meta_data_path).
    """
    parser = argparse.ArgumentParser(
        description="Create a cloud-init seed.iso file."
    )
    parser.add_argument(
        "-u",
        "--user-data",
        type=str,
        help="Path to user-data file",
    )
    parser.add_argument(
        "-m",
        "--meta-data",
        type=str,
        help="Path to meta-data file",
    )

    args = parser.parse_args()

    # If parameters are provided via CLI, use them
    if args.user_data or args.meta_data:
        user_path = Path(args.user_data) if args.user_data else DEFAULT_USER_DATA
        meta_path = Path(args.meta_data) if args.meta_data else DEFAULT_META_DATA
        return user_path, meta_path

    # Otherwise, fall back to interactive prompt
    print("No command-line arguments provided. Entering setup wizard...")

    user_input = (
        input(f"Enter path to user-data [{DEFAULT_USER_DATA}]: ").strip()
        or DEFAULT_USER_DATA
    )
    meta_input = (
        input(f"Enter path to meta-data [{DEFAULT_META_DATA}]: ").strip()
        or DEFAULT_META_DATA
    )

    return Path(user_input), Path(meta_input)


def main():
    """
    @brief      Main execution block for the ISO generation process.
    @details    Performs the following sequential steps:
                1. Retrieves file paths via get_input_paths().
                2. Validates that both targeted input files exist on the disk.
                3. Unlinks/deletes any pre-existing `seed.iso` file at the target destination.
                4. Initializes a new PyCdlib instance with Interchange Level 3, Joliet,
                   and Rock Ridge extensions enabled.
                5. Configures the volume label as 'CIDATA' (required by cloud-init).
                6. Writes the resulting ISO file to disk.

    @exception  SystemExit Exits with status code 1 if input files are missing.
    """
    # 1. Get file paths
    user_data_path, meta_data_path = get_input_paths()

    # 2. Validate existence
    if not user_data_path.exists():
        print(f"Error: Missing user-data file at '{user_data_path}'")
        sys.exit(1)

    if not meta_data_path.exists():
        print(f"Error: Missing meta-data file at '{meta_data_path}'")
        sys.exit(1)

    # 3. Clean up old ISO
    if OUT_ISO.exists():
        OUT_ISO.unlink()

    # 4. Generate the ISO
    print(f"\nGenerating ISO with:\n - {user_data_path}\n - {meta_data_path}")

    iso = pycdlib.PyCdlib()
    iso.new(
        interchange_level=3,
        joliet=True,
        rock_ridge="1.09",
        vol_ident="CIDATA",
        sys_ident="LINUX",
    )

    iso.add_file(
        str(user_data_path),
        iso_path="/USERDATA.;1",
        joliet_path="/user-data",
        rr_name="user-data",
    )

    iso.add_file(
        str(meta_data_path),
        iso_path="/METADATA.;1",
        joliet_path="/meta-data",
        rr_name="meta-data",
    )

    iso.write(str(OUT_ISO))
    iso.close()

    print(f"\nCreated: {OUT_ISO}")
    print("Volume label: CIDATA")
    print("Files in ISO:")
    print("  /user-data")
    print("  /meta-data")


if __name__ == "__main__":
    main()