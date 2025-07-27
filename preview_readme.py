#!/usr/bin/env python3
import markdown
import webbrowser
import os
import sys

# Read the README file
try:
    with open('README.md', 'r', encoding='utf-8') as f:
        md_content = f.read()
except FileNotFoundError:
    print("README.md not found!")
    sys.exit(1)

# Convert to HTML with extensions
try:
    import markdown
    html = markdown.markdown(md_content, extensions=['fenced_code', 'tables', 'toc'])
except ImportError:
    # Fallback without extensions
    html = md_content.replace('\n', '<br>\n')

# Create a complete HTML document with GitHub-like styling
full_html = f'''<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Grim README Preview</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            max-width: 1000px;
            margin: 0 auto;
            padding: 20px;
            background: #0d1117;
            color: #c9d1d9;
        }}
        h1, h2, h3, h4, h5, h6 {{
            color: #58a6ff;
            border-bottom: 1px solid #21262d;
            padding-bottom: 8px;
        }}
        h1 {{ font-size: 2em; }}
        h2 {{ font-size: 1.5em; }}
        h3 {{ font-size: 1.25em; }}
        code {{
            background: #161b22;
            padding: 2px 6px;
            border-radius: 6px;
            font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
            font-size: 85%;
        }}
        pre {{
            background: #161b22;
            padding: 16px;
            border-radius: 6px;
            overflow-x: auto;
            border: 1px solid #30363d;
        }}
        pre code {{
            background: none;
            padding: 0;
        }}
        blockquote {{
            border-left: 4px solid #58a6ff;
            padding-left: 16px;
            margin-left: 0;
            color: #8b949e;
        }}
        a {{
            color: #58a6ff;
            text-decoration: none;
        }}
        a:hover {{
            text-decoration: underline;
        }}
        table {{
            border-collapse: collapse;
            width: 100%;
            margin: 16px 0;
        }}
        th, td {{
            border: 1px solid #30363d;
            padding: 8px 12px;
            text-align: left;
        }}
        th {{
            background: #161b22;
            font-weight: 600;
        }}
        img {{
            max-width: 100%;
            height: auto;
            border-radius: 6px;
        }}
        .missing-svg {{
            background: #21262d;
            border: 2px dashed #30363d;
            padding: 40px;
            text-align: center;
            border-radius: 6px;
            margin: 16px 0;
            color: #8b949e;
        }}
        ul, ol {{
            margin: 16px 0;
            padding-left: 24px;
        }}
        li {{
            margin: 4px 0;
        }}
        hr {{
            border: none;
            border-top: 1px solid #21262d;
            margin: 24px 0;
        }}
    </style>
</head>
<body>
{html}
<script>
// Replace missing SVG references with placeholder
document.addEventListener('DOMContentLoaded', function() {{
    const imgs = document.querySelectorAll('img[src*=".svg"]');
    imgs.forEach(img => {{
        img.onerror = function() {{
            const placeholder = document.createElement('div');
            placeholder.className = 'missing-svg';
            placeholder.innerHTML = `
                <h3>📊 SVG Placeholder</h3>
                <p>Missing: ${{this.src.split('/').pop()}}</p>
                <p>Upload this file to the svg/ directory</p>
            `;
            this.parentNode.replaceChild(placeholder, this);
        }};
    }});
}});
</script>
</body>
</html>'''

# Write to preview file
preview_file = '/tmp/grim_readme_preview.html'
with open(preview_file, 'w', encoding='utf-8') as f:
    f.write(full_html)

print(f"README preview generated: {preview_file}")
print(f"Open in browser: file://{preview_file}")
print("\nTo view with firefox:")
print(f"firefox {preview_file} &")
print("\nTo view with any browser:")
print(f"xdg-open {preview_file} &")
