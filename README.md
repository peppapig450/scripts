# Scripts
Collection of all my scripts for Windows, MacOS, and all my Linux systems.

## Structure

- **automation/**: Home automation utilities (e.g., `home/fan_controller.py`)
- **c/**: C programs and helpers
- **devtools/**: Developer tooling and profiling scripts
- **misc/**: Miscellaneous one-off scripts
- **python/**: Python scripts
  - **analysis/**: Code and data analysis tools
  - **file_utils/**: File manipulation utilities
  - **git/**: Git-related tools
  - **image/**: Image processing scripts
  - **media/**: Media conversion tools
  - **misc/**: Miscellaneous scripts (color, mega subdirs)
  - **system/**: System-level utilities
  - **llm_utils/**: Tools for LLM-related tasks
- **shell/**: Shell scripts
  - **general/**: General-purpose scripts
  - **linux/**: Linux-specific scripts
  - **macos/**: macOS-specific scripts
  - **monitoring/**: Monitoring tools
  - **system/**: System management scripts
- **powershell/**: PowerShell scripts
  - **general/**: General-purpose utilities
  - **modules/**: PowerShell modules (e.g., RealPath)
- **unix/**: Functions, aliases, and systemd helpers for UNIX-like systems
- **windowmanager/**: Scripts for Hyprland and desktop theming

## Naming Conventions:
This is an overview of my wacky/unorthodox naming conventions.

### General Conventions:
* **Descriptive names:** Use descriptive names that convey the script's functionality. (eg. `configure_system`, `update_dependencies`).

### Language Specific Conventions:
* **Python:** Lowercase with underscores (e.g., `script_name.py`).

* **Shell (Bash, ZSH, POSIX sh / dash, Fish):** Lowercase with hyphens (e.g., `script-name.sh`).

* **Powershell:** PascalCase with verb-hyphen (e.g., `Get-ProcessInformation.ps1`).

**Explanation**:
* **PascalCase**: The first letter of each word is capitalized (e.g., `GetProcessInformation`).

* **Verb-Hyphen**: When the name starts with a verb (action word), it's followed by a hyphen (-) before the noun describing the target (e.g., `Get-Process`, `Set-Service`). This aligns with the naming convention for built-in PowerShell cmdlets.
