#!/usr/bin/env python3
import os
import re

# Read the README file
with open('README.md', 'r', encoding='utf-8') as f:
    content = f.read()

# Simple markdown-to-HTML conversion
def simple_md_to_html(text):
    # Headers
    text = re.sub(r'^# (.*)', r'<h1>\1</h1>', text, flags=re.MULTILINE)
    text = re.sub(r'^## (.*)', r'<h2>\1</h2>', text, flags=re.MULTILINE)
    text = re.sub(r'^### (.*)', r'<h3>\1</h3>', text, flags=re.MULTILINE)
    text = re.sub(r'^#### (.*)', r'<h4>\1</h4>', text, flags=re.MULTILINE)
    
    # Code blocks
    text = re.sub(r'```bash\n(.*?)\n```', r'<pre class="bash"><code>\1</code></pre>', text, flags=re.DOTALL)
    text = re.sub(r'```yaml\n(.*?)\n```', r'<pre class="yaml"><code>\1</code></pre>', text, flags=re.DOTALL)
    text = re.sub(r'```(.*?)\n(.*?)\n```', r'<pre><code>\2</code></pre>', text, flags=re.DOTALL)
    
    # Inline code
    text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
    
    # Bold
    text = re.sub(r'\*\*(.*?)\*\*', r'<strong>\1</strong>', text)
    
    # Links
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', text)
    
    # Images (including SVGs)
    text = re.sub(r'!\[([^\]]*)\]\(([^)]+)\)', r'<img src="\2" alt="\1" class="responsive-img">', text)
    
    # Line breaks
    text = text.replace('\n\n', '</p><p>')
    text = '<p>' + text + '</p>'
    
    # Fix headers in paragraphs
    text = re.sub(r'<p>(<h[1-6]>.*?</h[1-6]>)</p>', r'\1', text)
    text = re.sub(r'<p>(<pre.*?</pre>)</p>', r'\1', text, flags=re.DOTALL)
    
    return text

html_content = simple_md_to_html(content)

# Create complete HTML with styling
full_html = f'''<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Grim: Unified Data Protection Ecosystem - README Preview</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            max-width: 1000px;
            margin: 0 auto;
            padding: 20px;
            background: #0d1117;
            color: #c9d1d9;
        }}
        h1, h2, h3, h4 {{
            color: #58a6ff;
            border-bottom: 1px solid #21262d;
            padding-bottom: 8px;
            margin-top: 2em;
        }}
        h1 {{ font-size: 2.2em; text-align: center; }}
        h2 {{ font-size: 1.6em; }}
        h3 {{ font-size: 1.3em; }}
        h4 {{ font-size: 1.1em; }}
        code {{
            background: #161b22;
            padding: 3px 6px;
            border-radius: 6px;
            font-family: 'SFMono-Regular', Consolas, monospace;
            font-size: 90%;
            color: #ff7b72;
        }}
        pre {{
            background: #161b22;
            padding: 16px;
            border-radius: 6px;
            overflow-x: auto;
            border: 1px solid #30363d;
            margin: 16px 0;
        }}
        pre code {{
            background: none;
            padding: 0;
            color: #c9d1d9;
        }}
        .bash code {{
            color: #7ee787;
        }}
        .yaml code {{
            color: #ffa657;
        }}
        a {{
            color: #58a6ff;
            text-decoration: none;
        }}
        a:hover {{
            text-decoration: underline;
        }}
        .responsive-img {{
            max-width: 100%;
            height: auto;
            border-radius: 6px;
            margin: 16px 0;
        }}
        .missing-svg {{
            background: #21262d;
            border: 2px dashed #30363d;
            padding: 40px;
            text-align: center;
            border-radius: 6px;
            margin: 16px 0;
            color: #8b949e;
            display: block;
        }}
        strong {{
            color: #ffa657;
            font-weight: 600;
        }}
        p {{
            margin: 16px 0;
        }}
        .header-emoji {{
            font-size: 1.2em;
            margin-right: 8px;
        }}
        hr {{
            border: none;
            border-top: 1px solid #21262d;
            margin: 32px 0;
        }}
    </style>
</head>
<body>
{html_content}
<script>
document.addEventListener('DOMContentLoaded', function() {{
    // Handle missing SVG images
    const imgs = document.querySelectorAll('img[src*=".svg"]');
    imgs.forEach(img => {{
        img.onerror = function() {{
            const placeholder = document.createElement('div');
            placeholder.className = 'missing-svg';
            placeholder.innerHTML = 
                '<h3>📊 SVG Asset Placeholder</h3>' +
                '<p><strong>Missing:</strong> ' + this.src.split('/').pop() + '</p>' +
                '<p>Upload this file to the <code>svg/</code> directory</p>';
            this.parentNode.replaceChild(placeholder, this);
        }};
    }});
    
    // Add emoji styling to headers
    const headers = document.querySelectorAll('h2, h3');
    headers.forEach(header => {{
        const text = header.innerHTML;
        const emojiMatch = text.match(/^([🔥🧠🔒♻️📊🎮⚙️��🤝📄🆘🎯💀]+)\\s*/);
        if (emojiMatch) {{
            header.innerHTML = '<span class="header-emoji">' + emojiMatch[1] + '</span>' + text.replace(emojiMatch[0], '');
        }}
    }});
}});
</script>
</body>
</html>'''

# Write to preview file
preview_file = '/tmp/grim_readme_preview.html'
with open(preview_file, 'w', encoding='utf-8') as f:
    f.write(full_html)

print(f"✅ README preview generated successfully!")
print(f"📄 File: {preview_file}")
print(f"🌐 Size: {len(full_html):,} bytes")
print()
print("🚀 To view the preview:")
print(f"   firefox {preview_file} &")
print("   or")
print(f"   xdg-open {preview_file} &")
print()
print("📋 Preview includes:")
print("   • GitHub-style dark theme")
print("   • Responsive design")
print("   • SVG placeholder handling")
print("   • Syntax highlighting")
print("   • Emoji styling")
