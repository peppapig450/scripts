# Scripts
Collection of all my scripts for Windows, MacOS, and all my Linux systems.

## Structure

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
  - **vm/**: Virtual machine tools
  - **modules/**: PowerShell modules (e.g., RealPath)

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