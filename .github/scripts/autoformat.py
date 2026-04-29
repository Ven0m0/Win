#!/usr/bin/env python3
"""
PowerShell Auto-Format Script
Automatically fixes PowerShell formatting issues.
"""

import os
import re
from pathlib import Path
from typing import List, Tuple


# Repository formatting standards
MAX_LINE_LENGTH = 120
INDENT_SIZE = 2


def fix_bom(file_path: Path) -> bool:
    """Add UTF-8 BOM to file if missing."""
    try:
        with open(file_path, 'rb') as f:
            content = f.read()
        
        bom = b'\xef\xbb\xbf'
        if not content.startswith(bom):
            with open(file_path, 'wb') as f:
                f.write(bom + content)
            return True
    except Exception as e:
        print(f"Error fixing BOM for {file_path}: {e}")
    return False


def fix_file(file_path: Path, fix_line_length: bool = False) -> Tuple[int, List[str]]:
    """Fix formatting issues in a file."""
    issues_fixed = 0
    issues = []
    
    try:
        # Read with BOM handling
        with open(file_path, 'r', encoding='utf-8-sig') as f:
            lines = f.readlines()
        
        fixed_lines = []
        
        for i, line in enumerate(lines, 1):
            original = line
            modified = False
            
            # Normalize line endings
            line = line.replace('\r\n', '\n').replace('\r', '\n')
            
            # Skip if line is only whitespace/newline
            if line.strip() == '' or line == '\n':
                fixed_lines.append(line)
                continue
            
            content = line.rstrip('\n')
            
            # Check for tabs - convert to spaces
            if '\t' in content:
                # Simple tab to 2 spaces conversion
                content = content.replace('\t', '  ')
                modified = True
            
            # Check indentation (not multiple of 2)
            match = re.match(r'^(\s+)', content)
            if match:
                leading_spaces = len(match.group(1))
                if leading_spaces % INDENT_SIZE != 0:
                    # Round to nearest multiple of 2
                    new_leading = round(leading_spaces / INDENT_SIZE) * INDENT_SIZE
                    content = ' ' * new_leading + content.lstrip()
                    modified = True
                    issues_fixed += 1
            
            # Fix trailing whitespace
            stripped = content.rstrip()
            if stripped != content:
                content = stripped
                modified = True
                issues_fixed += 1
            
            # Handle line length
            if len(content) > MAX_LINE_LENGTH and not content.strip().startswith('#'):
                if fix_line_length:
                    # Truncate to max length (last resort)
                    content = content[:MAX_LINE_LENGTH]
                    modified = True
                    issues_fixed += 1
                else:
                    issues.append(f"{file_path}:{i}: Line exceeds {MAX_LINE_LENGTH} characters ({len(content)})")
            
            # Preserve line ending
            if modified:
                fixed_lines.append(content + '\n')
                issues_fixed += 1
            else:
                fixed_lines.append(line)
        
        if issues_fixed > 0 or issues:
            # Write back with UTF-8 BOM
            with open(file_path, 'w', encoding='utf-8-sig', newline='') as f:
                f.writelines(fixed_lines)
    
    except UnicodeDecodeError:
        issues.append(f"{file_path}: Encoding error")
    except Exception as e:
        issues.append(f"{file_path}: Error processing - {e}")
    
    return issues_fixed, issues


def main():
    """Main entry point."""
    import argparse
    parser = argparse.ArgumentParser(description='Auto-format PowerShell files')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be changed')
    parser.add_argument('--fix-bom', action='store_true', help='Fix BOM only')
    parser.add_argument('--fix-all', action='store_true', help='Fix everything including line length')
    parser.add_argument('files', nargs='*', help='Files to process (default: all PS files)')
    args = parser.parse_args()
    
    base_path = Path(__file__).parent.parent.parent
    
    if args.files:
        ps_files = [Path(f) for f in args.files]
    else:
        # Find all PowerShell files
        ps_files = list(base_path.glob("Scripts/**/*.ps1"))
        ps_files.extend(base_path.glob("Scripts/**/*.psm1"))
        ps_files.extend(base_path.glob("Scripts/**/*.psd1"))
        ps_files.extend(base_path.glob("user/**/*.ps1"))
        ps_files.extend(base_path.glob(".kilo/**/*.ps1"))
        ps_files.extend(base_path.glob("*.ps1"))
        ps_files.extend(base_path.glob("*.psd1"))
        ps_files = [f for f in ps_files if '.git' not in str(f) and 'node_modules' not in str(f)]
    
    ps_files = list(set(ps_files))
    ps_files.sort()
    
    print(f"Processing {len(ps_files)} PowerShell files...")
    print()
    
    total_fixed = 0
    total_bom_fixed = 0
    all_issues = []
    
    for ps_file in ps_files:
        if not ps_file.exists():
            continue
        
        # Fix BOM first
        if args.fix_bom or args.fix_all:
            if fix_bom(ps_file):
                total_bom_fixed += 1
                print(f"✅ Added BOM: {ps_file}")
        
        if args.fix_all:
            fixed, issues = fix_file(ps_file, fix_line_length=True)
            total_fixed += fixed
            all_issues.extend(issues)
            if fixed > 0:
                print(f"✏️  Fixed {fixed} issues: {ps_file}")
        elif issues:
            all_issues.extend(issues)
    
    print()
    print(f"Summary:")
    print(f"  BOM fixed: {total_bom_fixed}")
    print(f"  Issues fixed: {total_fixed}")
    print(f"  Remaining issues: {len(all_issues)}")
    
    if all_issues and not args.fix_all:
        print()
        print("Sample issues (run with --fix-all to attempt fixes):")
        for issue in all_issues[:20]:
            print(f"  {issue}")
        if len(all_issues) > 20:
            print(f"  ... and {len(all_issues) - 20} more")
    
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
