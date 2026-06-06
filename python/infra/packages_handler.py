import importlib
import subprocess
import sys


def import_or_install(module_name):
    """!
    @brief      Dynamically imports a Python module or attempts auto-installation.
    @details    Checks if a module is available in the current environment. If the
                module is missing and the script runs inside a virtual environment,
                it uses pip to install the dependency automatically. If running in a
                global system environment, installation is blocked to prevent pollution.

    @param      module_name    The string name of the module to import (e.g., 'pycdlib').

    @return     The imported module object on success.

    @note       If installation fails or is blocked by a global scope, the script
                will print an error to sys.stderr and terminate with exit code 1.
    """
    try:
        # Step 1: Attempt standard dynamic import
        return importlib.import_module(module_name)
    except ImportError:
        # Step 2: Internalized check for a virtual environment
        is_virtual_env = sys.prefix != sys.base_prefix

        if is_virtual_env:
            print(
                f"Dependency '{module_name}' not found. Virtual environment"
                " detected. Attempting auto-installation..."
            )
            try:
                # Step 3: Invoke pip inside the active virtual environment
                subprocess.check_call(
                    [sys.executable, "-m", "pip", "install", module_name]
                )
                print(f"Successfully installed {module_name}!")

                # Step 4: Retry the import after a successful installation
                return importlib.import_module(module_name)
            except Exception as exception:
                # Step 5: Handle installation failures gracefully
                print(
                    f"Error: Failed to automatically install '{module_name}'"
                    f" inside venv: {exception}",
                    file=sys.stderr,
                )
                sys.exit(1)
        else:
            # Step 6: Safeguard the global system environment
            print(
                f"Error: Missing dependency '{module_name}'.", file=sys.stderr
            )
            print(
                "Global environment detected. Auto-installation aborted to"
                " safeguard system packages.",
                file=sys.stderr,
            )
            print(
                f"Please activate a virtual environment or install it"
                f" manually via: pip install {module_name}",
                file=sys.stderr,
            )
            sys.exit(1)