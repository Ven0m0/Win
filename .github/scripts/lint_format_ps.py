#!/usr/bin/env python3
"""
PowerShell Lint and Format Script (Python fallback)
Validates PowerShell files against repository formatting standards.
"""

import os
import sys
import re
from pathlib import Path
from typing import List, Tuple


# Repository formatting standards
MAX_LINE_LENGTH = 120
INDENT_SIZE = 2


def check_bom(file_path: Path) -> List[str]:
    """Check if file has UTF-8 BOM."""
    issues = []
    try:
        with open(file_path, 'rb') as f:
            first_bytes = f.read(3)
            bom = b'\xef\xbb\xbf'  # UTF-8 BOM
            if first_bytes != bom:
                issues.append(f"{file_path}: Missing UTF-8 BOM")
    except Exception as e:
        issues.append(f"{file_path}: Error reading file - {e}")
    return issues


def check_file_formatting(file_path: Path) -> List[str]:
    """Check PowerShell file formatting."""
    issues = []
    try:
        # Read as text
        with open(file_path, 'r', encoding='utf-8-sig') as f:
            lines = f.readlines()
        
        for i, line in enumerate(lines, 1):
            original_line = line
            line = line.rstrip('\r\n')
            
            # Skip empty lines
            if not line.strip():
                continue
            
            # Check 1: No tabs
            if line.startswith('\t'):
                issues.append(f"{file_path}:{i}: Line uses tabs instead of spaces")
            
            # Check 2: Indentation multiple of 2
            match = re.match(r'^(\s+)', line)
            if match:
                leading_spaces = len(match.group(1))
                if leading_spaces % INDENT_SIZE != 0 and not line.strip().startswith('#'):
                    issues.append(f"{file_path}:{i}: Indentation not multiple of {INDENT_SIZE} spaces")
            
            # Check 3: Trailing whitespace
            stripped = line.rstrip()
            if stripped and stripped != line and stripped != line.rstrip():
                # Only flag if it's actual trailing whitespace, not just CR
                if line.endswith(' ') or (line.endswith('\t')):
                    issues.append(f"{file_path}:{i}: Trailing whitespace")
            
            # Check 4: Max line length (exclude comment-only lines)
            if len(line) > MAX_LINE_LENGTH and not line.strip().startswith('#'):
                issues.append(f"{file_path}:{i}: Line exceeds {MAX_LINE_LENGTH} characters ({len(line)})")
    
    except UnicodeDecodeError:
        issues.append(f"{file_path}: Encoding error - file may not be UTF-8")
    except Exception as e:
        issues.append(f"{file_path}: Error reading file - {e}")
    
    return issues


def main():
    """Main entry point."""
    script_dir = Path(__file__).parent.parent
    base_path = script_dir.parent
    
    # Find all PowerShell files
    ps_files = list(base_path.glob("Scripts/**/*.ps1"))
    ps_files.extend(base_path.glob("Scripts/**/*.psm1"))
    ps_files.extend(base_path.glob("Scripts/**/*.psd1"))
    ps_files.extend(base_path.glob("user/**/*.ps1"))
    ps_files.extend(base_path.glob(".kilo/**/*.ps1"))
    
    # Filter out test files and node_modules
    ps_files = [f for f in ps_files if '.git' not in str(f) and 'node_modules' not in str(f)]
    
    # Also include root level files
    ps_files.extend(base_path.glob("*.ps1"))
    ps_files.extend(base_path.glob("*.psd1"))
    
    # Remove duplicates
    ps_files = list(set(ps_files))
    ps_files.sort()
    
    print(f"Found {len(ps_files)} PowerShell files to check")
    print()
    
    all_issues = []
    
    for ps_file in ps_files:
        # Check BOM first
        bom_issues = check_bom(ps_file)
        all_issues.extend(bom_issues)
        
        # Check formatting
        format_issues = check_file_formatting(ps_file)
        all_issues.extend(format_issues)
    
    if all_issues:
        print(f"❌ Found {len(all_issues)} issues:")
        print()
        for issue in all_issues:
            print(f"  {issue}")
        print()
        return 1
    else:
        print("✅ No formatting issues found!")
        return 0


if __name__ == "__main__":
    sys.exit(main())
