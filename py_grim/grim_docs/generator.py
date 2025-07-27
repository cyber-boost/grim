#!/usr/bin/env python3
"""
Grim Documentation Generator

Scans all Python modules in py_grim, extracts docstrings, and generates Markdown and HTML documentation.
Also generates user guides, developer guides, and migration guides as stubs.
"""

import os
import sys
import importlib.util
import inspect
from pathlib import Path
from typing import List, Dict

DOCS_DIR = Path(__file__).parent
PROJECT_ROOT = DOCS_DIR.parent
MODULES_DIR = PROJECT_ROOT

OUTPUT_MD = DOCS_DIR / "grim_docs.md"
OUTPUT_HTML = DOCS_DIR / "grim_docs.html"

GUIDES = [
    ("User Guide", "How to use Grim system, CLI, and dashboard."),
    ("Developer Guide", "How to contribute, code structure, and best practices."),
    ("Migration Guide", "How to migrate from legacy systems to Grim Python/Go stack.")
]

def extract_module_doc(module_path: Path) -> Dict:
    """Extract docstrings from a Python module."""
    module_name = module_path.stem
    spec = importlib.util.spec_from_file_location(module_name, str(module_path))
    if not spec or not spec.loader:
        return {}
    module = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(module)
    except Exception:
        return {}
    doc = inspect.getdoc(module) or ""
    members = {}
    for name, obj in inspect.getmembers(module):
        if inspect.isfunction(obj) or inspect.isclass(obj):
            members[name] = inspect.getdoc(obj) or ""
    return {"name": module_name, "doc": doc, "members": members}

def scan_modules(base_dir: Path) -> List[Path]:
    """Recursively find all .py files in base_dir."""
    return [p for p in base_dir.rglob("*.py") if not p.name.startswith("_")]

def generate_markdown(docs: List[Dict]) -> str:
    md = "# Grim Python API Documentation\n\n"
    for module in docs:
        if not module or 'name' not in module:
            continue
        md += f"## Module `{module['name']}`\n\n{module['doc']}\n\n"
        for member, doc in module['members'].items():
            md += f"### `{member}`\n\n{doc}\n\n"
    md += "\n---\n\n"
    for title, desc in GUIDES:
        md += f"# {title}\n\n{desc}\n\n(Section to be completed.)\n\n"
    return md

def generate_html(md: str) -> str:
    import markdown
    html = markdown.markdown(md, extensions=["fenced_code", "tables"])
    return f"""
<!DOCTYPE html>
<html lang='en'>
<head>
    <meta charset='UTF-8'>
    <title>Grim Python API Documentation</title>
    <style>
        body {{ font-family: 'Segoe UI', Arial, sans-serif; margin: 2em; background: #f9f9fb; color: #222; }}
        h1, h2, h3 {{ color: #4b3fa7; }}
        pre, code {{ background: #f4f4f4; border-radius: 4px; padding: 2px 6px; }}
        hr {{ border: none; border-top: 1px solid #ddd; margin: 2em 0; }}
    </style>
</head>
<body>
{html}
</body>
</html>
"""

def main():
    modules = scan_modules(MODULES_DIR)
    docs = [extract_module_doc(m) for m in modules]
    md = generate_markdown(docs)
    with open(OUTPUT_MD, "w") as f:
        f.write(md)
    try:
        html = generate_html(md)
        with open(OUTPUT_HTML, "w") as f:
            f.write(html)
    except ImportError:
        pass
    print(f"Documentation generated: {OUTPUT_MD}\nHTML version: {OUTPUT_HTML}")

if __name__ == "__main__":
    main() 