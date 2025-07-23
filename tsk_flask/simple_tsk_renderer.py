#!/usr/bin/env python3
"""
Simple TuskLang Template Renderer
Synchronous template rendering using official TuskTsk package
"""

import re
import logging
from typing import Dict, Any, List

logger = logging.getLogger(__name__)

class SimpleTskRenderer:
    """Simple synchronous TuskLang template renderer"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
    
    def render(self, template_content: str, context: Dict[str, Any] = None) -> str:
        """Render template with TuskLang syntax"""
        if not context:
            context = {}
        
        result = template_content
        
        # Handle TuskLang extends and content blocks FIRST (before other processing)
        result = self._process_tsk_extends(result, context)
        
        # Handle Jinja2 variable syntax: {{ variable }} and {{ object.property }}
        jinja2_nested_pattern = r'\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)*)\s*\}\}'
        
        def replace_jinja2_nested(match):
            try:
                path = match.group(1).strip()
                parts = path.split('.')
                current = context
                
                for part in parts:
                    if isinstance(current, dict) and part in current:
                        current = current[part]
                    else:
                        return match.group(0)  # Return original if path not found
                
                return str(current)
            except Exception as e:
                self.logger.warning(f"Jinja2 nested object access failed for {match.group(1)}: {e}")
                return match.group(0)
        
        result = re.sub(jinja2_nested_pattern, replace_jinja2_nested, result)
        
        # Handle Jinja2 simple variable substitution: {{ variable }}
        jinja2_simple_pattern = r'\{\{\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*\}\}'
        
        def replace_jinja2_simple(match):
            try:
                key = match.group(1).strip()
                if key in context:
                    return str(context[key])
                else:
                    return match.group(0)  # Return original if key not found
            except Exception as e:
                self.logger.warning(f"Jinja2 simple variable substitution failed for {match.group(1)}: {e}")
                return match.group(0)
        
        result = re.sub(jinja2_simple_pattern, replace_jinja2_simple, result)
        
        # Handle TuskLang nested object access: $object.property (do this BEFORE simple variable substitution)
        nested_pattern = r'\$([a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)*)'
        
        def replace_nested(match):
            try:
                path = match.group(1)
                parts = path.split('.')
                current = context
                
                for part in parts:
                    if isinstance(current, dict) and part in current:
                        current = current[part]
                    else:
                        return match.group(0)  # Return original if path not found
                
                return str(current)
            except Exception as e:
                self.logger.warning(f"Nested object access failed for {match.group(1)}: {e}")
                return match.group(0)
        
        result = re.sub(nested_pattern, replace_nested, result)
        
        # Handle TuskLang simple variable substitution: $variable (do this AFTER nested object access)
        for key, value in context.items():
            placeholder = f"${key}"
            if placeholder in result:
                result = result.replace(placeholder, str(value))
        
        # Handle Jinja2 conditionals: {% if condition %} ... {% endif %}
        result = self._process_jinja2_conditionals(result, context)
        
        # Handle Jinja2 loops: {% for item in items %} ... {% endfor %}
        result = self._process_jinja2_loops(result, context)
        
        # Handle TuskLang conditionals: $if condition ... $endif
        result = self._process_conditionals(result, context)
        
        # Handle TuskLang inline conditionals: $if condition value $endif
        result = self._process_inline_conditionals(result, context)
        
        # Handle TuskLang loops: $for item in items ... $endfor
        result = self._process_loops(result, context)
        
        # Handle includes: $include template
        result = self._process_includes(result, context)
        
        # Handle template inheritance: $extends template
        result = self._process_extends(result, context)
        
        # Handle blocks: $block name ... $endblock
        result = self._process_blocks(result, context)
        
        return result
    
    def _process_conditionals(self, content: str, context: Dict[str, Any]) -> str:
        """Process $if conditionals"""
        lines = content.split('\n')
        processed_lines = []
        i = 0
        
        while i < len(lines):
            line = lines[i].strip()
            
            if line.startswith('$if '):
                condition = line[4:].strip()
                self.logger.info(f"Processing conditional: $if {condition}")
                # Evaluate condition
                condition_result = self._evaluate_condition(condition, context)
                self.logger.info(f"Condition result: {condition_result}")
                
                if condition_result:
                    # Skip the $if line but keep the content
                    i += 1
                else:
                    # Skip until $endif
                    while i < len(lines) and lines[i].strip() != '$endif':
                        i += 1
                    if i < len(lines):
                        i += 1  # Skip the $endif line
                    continue
            elif line == '$endif':
                # Skip $endif line
                i += 1
                continue
            else:
                processed_lines.append(lines[i])
                i += 1
        
        return '\n'.join(processed_lines)
    
    def _process_inline_conditionals(self, content: str, context: Dict[str, Any]) -> str:
        """Process inline conditionals: $if condition value $endif"""
        # Pattern to match: $if condition value $endif
        inline_pattern = r'\$if\s+([^$]+?)\s+([^$]+?)\s+\$endif'
        
        def replace_inline_conditional(match):
            try:
                condition = match.group(1).strip()
                value = match.group(2).strip()
                
                # Evaluate condition
                condition_result = self._evaluate_condition(condition, context)
                
                if condition_result:
                    return value
                else:
                    return ''
            except Exception as e:
                self.logger.warning(f"Inline conditional evaluation failed: {e}")
                return match.group(0)
        
        return re.sub(inline_pattern, replace_inline_conditional, content)
    
    def _process_loops(self, content: str, context: Dict[str, Any]) -> str:
        """Process $for loops"""
        lines = content.split('\n')
        processed_lines = []
        i = 0
        
        while i < len(lines):
            line = lines[i].strip()
            
            if line.startswith('$for '):
                # Extract: $for item in items
                parts = line[5:].strip().split(' in ')
                if len(parts) == 2:
                    item_var = parts[0].strip()
                    collection = parts[1].strip()
                    
                    # Get collection from context
                    collection_data = context.get(collection, [])
                    if isinstance(collection_data, (list, tuple)):
                        # Find loop body
                        loop_start = i + 1
                        loop_end = i
                        j = i + 1
                        while j < len(lines) and lines[j].strip() != '$endfor':
                            j += 1
                        loop_end = j
                        
                        # Process loop
                        for item in collection_data:
                            # Create temporary context
                            temp_context = context.copy()
                            temp_context[item_var] = item
                            
                            # Process loop body
                            for k in range(loop_start, loop_end):
                                loop_line = lines[k]
                                # Replace variables in loop line
                                for temp_key, temp_value in temp_context.items():
                                    loop_line = loop_line.replace(f'${temp_key}', str(temp_value))
                                processed_lines.append(loop_line)
                        
                        # Skip to endfor
                        i = loop_end
                        if i < len(lines):
                            i += 1  # Skip the $endfor line
                        continue
                    else:
                        # Collection is not iterable, skip loop
                        while i < len(lines) and lines[i].strip() != '$endfor':
                            i += 1
                        if i < len(lines):
                            i += 1  # Skip the $endfor line
                        continue
                else:
                    processed_lines.append(lines[i])
                    i += 1
            elif line == '$endfor':
                # Skip $endfor line
                i += 1
                continue
            else:
                processed_lines.append(lines[i])
                i += 1
        
        return '\n'.join(processed_lines)
    
    def _process_includes(self, content: str, context: Dict[str, Any]) -> str:
        """Process Jinja2 include directives"""
        lines = content.split('\n')
        processed_lines = []
        
        for line in lines:
            # Handle {% include "template.html" %}
            if line.strip().startswith('{% include '):
                import re
                include_match = re.search(r'{%\s+include\s+["\']([^"\']+)["\']\s+%}', line.strip())
                if include_match:
                    include_template = include_match.group(1)
                    self.logger.info(f"Include directive found: {include_template}")
                    
                    # Load and process the included template
                    try:
                        import os
                        template_dir = os.path.dirname(__file__)
                        include_template_path = os.path.join(template_dir, 'grim', include_template)
                        
                        if os.path.exists(include_template_path):
                            with open(include_template_path, 'r', encoding='utf-8') as f:
                                include_content = f.read()
                            
                            # Process the included content recursively
                            processed_include = self.render(include_content, context)
                            processed_lines.append(processed_include)
                        else:
                            self.logger.warning(f"Include template not found: {include_template_path}")
                            processed_lines.append(f"<!-- Include not found: {include_template} -->")
                    except Exception as e:
                        self.logger.warning(f"Include processing failed for {include_template}: {e}")
                        processed_lines.append(f"<!-- Include error: {include_template} -->")
                else:
                    processed_lines.append(line)
            else:
                processed_lines.append(line)
        
        return '\n'.join(processed_lines)
    
    def _process_jinja2_conditionals(self, content: str, context: Dict[str, Any]) -> str:
        """Process Jinja2 {% if conditionals %}"""
        lines = content.split('\n')
        processed_lines = []
        i = 0
        
        while i < len(lines):
            line = lines[i].strip()
            
            # Handle {% if condition %}
            if line.startswith('{% if '):
                # Extract condition from {% if condition %}
                import re
                condition_match = re.search(r'{%\s+if\s+(.+?)\s+%}', line)
                if condition_match:
                    condition = condition_match.group(1).strip()
                    self.logger.info(f"Processing Jinja2 conditional: {{% if {condition} %}}")
                    # Evaluate condition
                    condition_result = self._evaluate_jinja2_condition(condition, context)
                    self.logger.info(f"Jinja2 condition result: {condition_result}")
                    
                    if condition_result:
                        # Skip the {% if %} line but keep the content
                        i += 1
                    else:
                        # Skip until {% endif %}
                        while i < len(lines) and not lines[i].strip().startswith('{% endif'):
                            i += 1
                        if i < len(lines):
                            i += 1  # Skip the {% endif %} line
                        continue
                else:
                    processed_lines.append(lines[i])
                    i += 1
            elif line.startswith('{% endif'):
                # Skip {% endif %} line
                i += 1
                continue
            else:
                processed_lines.append(lines[i])
                i += 1
        
        return '\n'.join(processed_lines)
    
    def _process_jinja2_loops(self, content: str, context: Dict[str, Any]) -> str:
        """Process Jinja2 {% for item in items %} loops"""
        lines = content.split('\n')
        processed_lines = []
        i = 0
        
        while i < len(lines):
            line = lines[i].strip()
            
            # Handle {% for item in items %}
            if line.startswith('{% for '):
                # Extract loop info from {% for item in items %}
                import re
                loop_match = re.search(r'{%\s+for\s+(\w+)\s+in\s+(\w+)\s+%}', line)
                if loop_match:
                    item_var = loop_match.group(1)
                    collection_var = loop_match.group(2)
                    self.logger.info(f"Processing Jinja2 loop: {{% for {item_var} in {collection_var} %}}")
                    
                    # Find the collection in context
                    if collection_var in context:
                        collection = context[collection_var]
                        if isinstance(collection, (list, tuple)):
                            # Collect content between {% for %} and {% endfor %}
                            loop_content = []
                            i += 1  # Skip the {% for %} line
                            
                            while i < len(lines) and not lines[i].strip().startswith('{% endfor'):
                                loop_content.append(lines[i])
                                i += 1
                            
                            if i < len(lines):
                                i += 1  # Skip the {% endfor %} line
                            
                            # Process the loop content for each item
                            for item in collection:
                                # Create a temporary context with the loop variable
                                temp_context = context.copy()
                                temp_context[item_var] = item
                                
                                # Process the loop content with the temporary context
                                loop_text = '\n'.join(loop_content)
                                processed_loop = self.render(loop_text, temp_context)
                                processed_lines.append(processed_loop)
                        else:
                            # Collection is not iterable, skip the loop
                            while i < len(lines) and not lines[i].strip().startswith('{% endfor'):
                                i += 1
                            if i < len(lines):
                                i += 1  # Skip the {% endfor %} line
                    else:
                        # Collection not found, skip the loop
                        while i < len(lines) and not lines[i].strip().startswith('{% endfor'):
                            i += 1
                        if i < len(lines):
                            i += 1  # Skip the {% endfor %} line
                else:
                    processed_lines.append(lines[i])
                    i += 1
            elif line.startswith('{% endfor'):
                # Skip {% endfor %} line
                i += 1
                continue
            else:
                processed_lines.append(lines[i])
                i += 1
        
        return '\n'.join(processed_lines)
    
    def _evaluate_jinja2_condition(self, condition: str, context: Dict[str, Any]) -> bool:
        """Evaluate a Jinja2 condition"""
        try:
            # Handle simple conditions like "variable", "variable and variable2", etc.
            if ' and ' in condition:
                parts = condition.split(' and ')
                return all(self._evaluate_simple_condition(part.strip(), context) for part in parts)
            elif ' or ' in condition:
                parts = condition.split(' or ')
                return any(self._evaluate_simple_condition(part.strip(), context) for part in parts)
            else:
                return self._evaluate_simple_condition(condition.strip(), context)
        except Exception as e:
            self.logger.warning(f"Jinja2 condition evaluation failed: {e}")
            return False
    
    def _evaluate_simple_condition(self, condition: str, context: Dict[str, Any]) -> bool:
        """Evaluate a simple Jinja2 condition"""
        try:
            # Handle variable existence
            if condition in context:
                value = context[condition]
                if isinstance(value, (list, tuple)):
                    return len(value) > 0
                elif isinstance(value, (str, bytes)):
                    return len(value) > 0
                elif isinstance(value, (int, float)):
                    return value != 0
                else:
                    return bool(value)
            else:
                # Check if it's a nested condition
                parts = condition.split('.')
                current = context
                
                for part in parts:
                    if isinstance(current, dict) and part in current:
                        current = current[part]
                    else:
                        return False
                
                if isinstance(current, (list, tuple)):
                    return len(current) > 0
                elif isinstance(current, (str, bytes)):
                    return len(current) > 0
                elif isinstance(current, (int, float)):
                    return current != 0
                else:
                    return bool(current)
        except Exception as e:
            self.logger.warning(f"Simple condition evaluation failed: {e}")
            return False
    
    def _process_tsk_extends(self, content: str, context: Dict[str, Any]) -> str:
        """Process TuskLang template inheritance: $extends and $content"""
        import re
        import os
        
        lines = content.split('\n')
        extends_template = None
        content_block = []
        in_content = False
        
        # First pass: find extends and collect content
        for i, line in enumerate(lines):
            line_stripped = line.strip()
            
            # Handle $extends "template.html"
            if line_stripped.startswith('$extends '):
                # Extract template name from $extends "template.html"
                extends_match = re.search(r'\$extends\s+["\']([^"\']+)["\']', line_stripped)
                if extends_match:
                    extends_template = extends_match.group(1)
                    self.logger.info(f"TuskLang extends template: {extends_template}")
                continue
            
            # Handle $content
            elif line_stripped == '$content':
                in_content = True
                continue
            
            # Handle $endcontent (optional end marker)
            elif line_stripped == '$endcontent':
                in_content = False
                continue
            
            elif in_content:
                content_block.append(lines[i])  # Use original line, not stripped
        
        # If we have an extends template, load and process it
        if extends_template:
            try:
                # Load the parent template
                template_dir = os.path.dirname(__file__)
                parent_template_path = os.path.join(template_dir, 'grim', extends_template)
                
                if os.path.exists(parent_template_path):
                    with open(parent_template_path, 'r', encoding='utf-8') as f:
                        parent_content = f.read()
                    
                    # Replace $content with the collected content
                    content_replacement = '\n'.join(content_block)
                    parent_content = parent_content.replace('$content', content_replacement)
                    
                    # Recursively process the parent template
                    return self.render(parent_content, context)
                else:
                    self.logger.warning(f"Parent template not found: {parent_template_path}")
            except Exception as e:
                self.logger.warning(f"TuskLang template inheritance failed: {e}")
        
        return content

    def _process_extends(self, content: str, context: Dict[str, Any]) -> str:
        """Process Jinja2 template inheritance: {% extends %} and {% block %}"""
        import re
        import os
        
        lines = content.split('\n')
        extends_template = None
        block_content = {}
        current_block = None
        in_block = False
        
        # First pass: find extends and collect blocks
        for i, line in enumerate(lines):
            line_stripped = line.strip()
            
            # Handle {% extends "template.html" %}
            if line_stripped.startswith('{% extends '):
                # Extract template name from {% extends "template.html" %}
                extends_match = re.search(r'{%\s+extends\s+["\']([^"\']+)["\']\s+%}', line_stripped)
                if extends_match:
                    extends_template = extends_match.group(1)
                    self.logger.info(f"Extends template: {extends_template}")
                continue
            
            # Handle {% block name %}
            elif line_stripped.startswith('{% block '):
                # Extract block name from {% block name %}
                block_match = re.search(r'{%\s+block\s+(\w+)\s+%}', line_stripped)
                if block_match:
                    block_name = block_match.group(1)
                    current_block = block_name
                    in_block = True
                    block_content[block_name] = []
                    self.logger.info(f"Found block: {block_name}")
                continue
            
            # Handle {% endblock %}
            elif line_stripped == '{% endblock %}':
                in_block = False
                current_block = None
                continue
            
            elif in_block and current_block:
                block_content[current_block].append(lines[i])  # Use original line, not stripped
        
        # If we have an extends template, load and process it
        if extends_template:
            try:
                # Load the parent template
                template_dir = os.path.dirname(__file__)
                parent_template_path = os.path.join(template_dir, 'grim', extends_template)
                
                if os.path.exists(parent_template_path):
                    with open(parent_template_path, 'r', encoding='utf-8') as f:
                        parent_content = f.read()
                    
                    # Replace {% block name %} ... {% endblock %} with content
                    for block_name, content in block_content.items():
                        # Find the block in parent template and replace it
                        block_pattern = r'{%\s+block\s+' + re.escape(block_name) + r'\s+%}.*?{%\s+endblock\s+%}'
                        replacement = '\n'.join(content)
                        parent_content = re.sub(block_pattern, replacement, parent_content, flags=re.DOTALL)
                    
                    # Recursively process the parent template
                    return self.render(parent_content, context)
                else:
                    self.logger.warning(f"Parent template not found: {parent_template_path}")
            except Exception as e:
                self.logger.warning(f"Template inheritance failed: {e}")
        
        return content
    
    def _process_blocks(self, content: str, context: Dict[str, Any]) -> str:
        """Process Jinja2 block directives"""
        lines = content.split('\n')
        processed_lines = []
        
        for line in lines:
            if (line.strip().startswith('{% block ') or 
                line.strip() == '{% endblock %}' or
                line.strip().startswith('{% extends ') or
                line.strip().startswith('{% include ')):
                # Remove Jinja2 directives as they're handled by other methods
                self.logger.info(f"Jinja2 directive found: {line.strip()}")
                continue
            else:
                processed_lines.append(line)
        
        return '\n'.join(processed_lines)
    
    def _evaluate_condition(self, condition: str, context: Dict[str, Any]) -> bool:
        """Evaluate a TuskLang condition"""
        try:
            # Simple condition evaluation
            if condition in context:
                value = context[condition]
                if isinstance(value, (list, tuple)):
                    return len(value) > 0
                elif isinstance(value, (str, bytes)):
                    return len(value) > 0
                elif isinstance(value, (int, float)):
                    return value != 0
                else:
                    return bool(value)
            else:
                # Check if it's a nested condition
                parts = condition.split('.')
                current = context
                
                for part in parts:
                    if isinstance(current, dict) and part in current:
                        current = current[part]
                    else:
                        return False
                
                return bool(current)
        except Exception as e:
            self.logger.warning(f"Condition evaluation failed for '{condition}': {e}")
            return False

# Global instance
simple_tsk_renderer = SimpleTskRenderer()

def render_simple_tsk_template(template_content: str, context: Dict[str, Any] = None) -> str:
    """Render template with simple TuskLang processing"""
    return simple_tsk_renderer.render(template_content, context) 