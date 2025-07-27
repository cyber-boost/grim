#!/usr/bin/env python3
"""
Grim Reaper Scanner Module
"""

import sys
import argparse
from pathlib import Path
import os
import hashlib
import time
import json

class GrimScanner:
    """Security scanning functionality for Grim Reaper"""
    
    def __init__(self):
        self.version = "1.0.0"
    
    def scan(self, path, **kwargs):
        """Perform security scan"""
        print(f"🗡️ Grim Reaper Python Scanner v{self.version}")
        print(f"Scanning path: {path}")
        
        results = []
        scan_start = time.time()
        
        path_obj = Path(path)
        if not path_obj.exists():
            print(f"❌ Path does not exist: {path}")
            return 1
        
        try:
            if path_obj.is_file():
                result = self._scan_file(path_obj, kwargs.get('include_hash', False))
                if result:
                    results.append(result)
            else:
                # Scan directory
                for item in path_obj.rglob('*' if kwargs.get('recursive', True) else '*'):
                    if item.is_file():
                        result = self._scan_file(item, kwargs.get('include_hash', False))
                        if result:
                            results.append(result)
        except Exception as e:
            print(f"❌ Error scanning {path}: {e}")
            return 1
        
        scan_duration = time.time() - scan_start
        
        # Generate summary
        summary = {
            "scan_path": str(path),
            "total_files": len(results),
            "scan_duration_seconds": scan_duration,
            "security_issues": self._analyze_security_issues(results),
            "file_types": self._analyze_file_types(results),
            "largest_files": sorted(results, key=lambda x: x.get('size', 0), reverse=True)[:10]
        }
        
        output = {
            "scanner": "Grim Python Security Scanner",
            "version": self.version,
            "results": results,
            "summary": summary
        }
        
        if kwargs.get('output'):
            with open(kwargs['output'], 'w') as f:
                json.dump(output, f, indent=2, default=str)
            print(f"✅ Results saved to: {kwargs['output']}")
        else:
            print(json.dumps(output, indent=2, default=str))
        
        return 0
    
    def _scan_file(self, file_path, include_hash=False):
        """Scan individual file"""
        try:
            stat = file_path.stat()
            result = {
                "path": str(file_path),
                "size": stat.st_size,
                "modified": time.ctime(stat.st_mtime),
                "permissions": oct(stat.st_mode)[-3:],
                "file_type": self._detect_file_type(file_path),
                "security_flags": self._check_security_flags(file_path)
            }
            
            if include_hash and stat.st_size < 100 * 1024 * 1024:  # Only hash files < 100MB
                result["md5"] = self._calculate_hash(file_path, 'md5')
                result["sha256"] = self._calculate_hash(file_path, 'sha256')
            
            return result
        except Exception as e:
            print(f"⚠️  Error scanning file {file_path}: {e}")
            return None
    
    def _detect_file_type(self, file_path):
        """Detect file type"""
        suffix = file_path.suffix.lower()
        type_map = {
            '.py': 'Python script',
            '.sh': 'Shell script',
            '.js': 'JavaScript',
            '.php': 'PHP script',
            '.sql': 'SQL script',
            '.txt': 'Text file',
            '.log': 'Log file',
            '.conf': 'Configuration',
            '.cfg': 'Configuration',
            '.ini': 'Configuration',
            '.json': 'JSON data',
            '.xml': 'XML data',
            '.yaml': 'YAML data',
            '.yml': 'YAML data'
        }
        return type_map.get(suffix, 'Unknown')
    
    def _check_security_flags(self, file_path):
        """Check for security concerns"""
        flags = []
        
        # Check permissions
        stat = file_path.stat()
        if stat.st_mode & 0o002:  # World writable
            flags.append("world_writable")
        if stat.st_mode & 0o111:  # Executable
            flags.append("executable")
        
        # Check file content for security patterns (only for small text files)
        if file_path.suffix.lower() in ['.py', '.sh', '.js', '.php', '.sql', '.txt', '.conf']:
            try:
                if stat.st_size < 1024 * 1024:  # Only scan files < 1MB
                    content = file_path.read_text(errors='ignore').lower()
                    
                    security_patterns = [
                        ('password', 'contains_password'),
                        ('secret', 'contains_secret'),
                        ('api_key', 'contains_api_key'),
                        ('private_key', 'contains_private_key'),
                        ('token', 'contains_token'),
                        ('sudo', 'contains_sudo'),
                        ('chmod 777', 'dangerous_permissions'),
                        ('rm -rf', 'dangerous_commands'),
                        ('eval(', 'eval_usage'),
                        ('exec(', 'exec_usage')
                    ]
                    
                    for pattern, flag in security_patterns:
                        if pattern in content:
                            flags.append(flag)
            except:
                pass  # Ignore read errors
        
        return flags
    
    def _calculate_hash(self, file_path, algorithm):
        """Calculate file hash"""
        try:
            hash_obj = hashlib.new(algorithm)
            with open(file_path, 'rb') as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_obj.update(chunk)
            return hash_obj.hexdigest()
        except:
            return None
    
    def _analyze_security_issues(self, results):
        """Analyze security issues from scan results"""
        issues = {}
        for result in results:
            for flag in result.get('security_flags', []):
                issues[flag] = issues.get(flag, 0) + 1
        return issues
    
    def _analyze_file_types(self, results):
        """Analyze file types from scan results"""
        types = {}
        for result in results:
            file_type = result.get('file_type', 'Unknown')
            types[file_type] = types.get(file_type, 0) + 1
        return types
    
    def main(self, args=None):
        """Main entry point for scan command"""
        if args is None:
            args = sys.argv[1:]
        
        parser = argparse.ArgumentParser(
            description="Grim Reaper Python Security Scanner",
            formatter_class=argparse.RawDescriptionHelpFormatter,
            epilog="""
Examples:
  python3 scanner.py /path/to/scan
  python3 scanner.py --path /path/to/scan --recursive
  python3 scanner.py /path/to/scan --output results.json
  python3 scanner.py /path/to/scan --hash --recursive
            """
        )
        
        parser.add_argument(
            "path",
            nargs='?',
            default=".",
            help="Path to scan (default: current directory)"
        )
        
        parser.add_argument(
            "--path", "-p",
            help="Alternative way to specify path to scan"
        )
        
        parser.add_argument(
            "--recursive", "-r",
            action="store_true",
            default=True,
            help="Scan recursively (default: True)"
        )
        
        parser.add_argument(
            "--output", "-o",
            help="Output file for scan results (JSON format)"
        )
        
        parser.add_argument(
            "--hash",
            action="store_true",
            help="Calculate file hashes (MD5/SHA256)"
        )
        
        parser.add_argument(
            "--version",
            action="version",
            version=f"Grim Python Scanner {self.version}"
        )
        
        parsed_args = parser.parse_args(args)
        
        # Use --path if provided, otherwise use positional argument
        scan_path = parsed_args.path if parsed_args.path else parsed_args.path
        if parsed_args.path:
            scan_path = parsed_args.path
        
        return self.scan(
            scan_path,
            recursive=parsed_args.recursive,
            output=parsed_args.output,
            include_hash=parsed_args.hash
        )

def main():
    """Main function for console script entry point"""
    scanner = GrimScanner()
    sys.exit(scanner.main())

if __name__ == "__main__":
    main() 