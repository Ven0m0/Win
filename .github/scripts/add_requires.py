#!/usr/bin/env python3
"""
Add proper #Requires directives to PowerShell scripts.
"""

import os
import re
from pathlib import Path


# Scripts that require administrator privileges
ADMIN_SCRIPTS = {
    'Backup-GameConfigs.ps1',
    'DLSS-force-latest.ps1',
    'UltimateDiskCleanup.ps1',
    'additional-maintenance.ps1',
    'allow-scripts.ps1',
    'debloat-windows.ps1',
    'fix-system.ps1',
    'gpu-display-manager.ps1',
    'shader-cache.ps1',
    'system-settings-manager.ps1',
    # arc-raiders
    'cleanup-arc-raiders.ps1',
    'start-arc-raiders.ps1',
}

# Test files should NOT have admin requirement
TEST_FILES = {f for f in os.listdir('Scripts') if f.endswith('.Tests.ps1')}
TEST_FILES.update({f for f in os.listdir('Scripts/arc-raiders') if f.endswith('.Tests.ps1')})


def add_requires_to_file(file_path: Path) -> bool:
    """Add #Requires directives to a PowerShell script."""
    try:
        with open(file_path, 'r', encoding='utf-8-sig') as f:
            content = f.read()
        
        lines = content.split('\n')
        
        # Check if already has #Requires -Version
        has_version = any('#Requires -Version' in line for line in lines[:10])
        
        # Check if already has our exact format
        has_our_requires = any(
            line.strip() in ['#Requires -Version 5.1', '#Requires -Version 5.1']
            for line in lines[:5]
        )
        
        if has_our_requires:
            print(f"  ⏭️  Already has #Requires: {file_path}")
            return False
        
        # Build new requires line
        script_name = file_path.name
        requires_lines = []
        
        if not has_version:
            requires_lines.append('#Requires -Version 5.1')
        
        if script_name in ADMIN_SCRIPTS and script_name not in TEST_FILES:
            if not any('#Requires -RunAsAdministrator' in line for line in lines[:10]):
                requires_lines.append('#Requires -RunAsAdministrator')
        
        if not requires_lines:
            print(f"  ⏭️  No changes needed: {file_path}")
            return False
        
        # Find where to insert (after #!/usr/bin/env pwsh if present, or at start)
        new_lines = []
        inserted = False
        
        for i, line in enumerate(lines):
            if not inserted:
                # Skip empty lines at the start
                if i == 0 and line.strip() == '':
                    new_lines.append(line)
                    continue
                
                # If first line is a shebang, insert after it
                if i == 0 and line.startswith('#!'):
                    new_lines.append(line)
                    # Add blank line after shebang
                    if lines[i+1].strip() != '':
                        new_lines.append('')
                    new_lines.extend(requires_lines)
                    new_lines.append('')
                    inserted = True
                    continue
                
                # Otherwise insert at the start
                new_lines.extend(requires_lines)
                new_lines.append('')
                inserted = True
            
            new_lines.append(line)
        
        if not inserted:
            new_lines = requires_lines + [''] + lines
        
        # Write back
        with open(file_path, 'w', encoding='utf-8-sig', newline='') as f:
            f.write('\n'.join(new_lines))
        
        print(f"  ✅ Updated: {file_path}")
        return True
    
    except Exception as e:
        print(f"  ❌ Error: {file_path} - {e}")
        return False


def main():
    """Main entry point."""
    scripts_dir = Path('Scripts')
    count = 0
    
    print("Adding #Requires directives to PowerShell scripts...")
    print()
    
    # Process main scripts
    for ps1_file in sorted(scripts_dir.glob('*.ps1')):
        if add_requires_to_file(ps1_file):
            count += 1
    
    # Process arc-raiders scripts
    arc_raiders_dir = scripts_dir / 'arc-raiders'
    if arc_raiders_dir.exists():
        for ps1_file in sorted(arc_raiders_dir.glob('*.ps1')):
            if add_requires_to_file(ps1_file):
                count += 1
    
    print()
    print(f"Updated {count} files.")
    
    return 0


if __name__ == '__main__':
    import sys
    sys.exit(main())
