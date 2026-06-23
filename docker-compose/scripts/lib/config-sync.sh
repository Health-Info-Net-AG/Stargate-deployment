#!/bin/bash
# =============================================================================
# Shared library: sync new variables from example config to active config.
#
# Sourced by update.sh -- NOT meant to be executed directly.
#
# Appends any variables present in the example template but missing from the
# active customer-config.sh. Never overwrites existing values. This ensures
# that new configuration knobs introduced in updates are visible to operators
# with their default values.
# =============================================================================

# sync_customer_config EXAMPLE_FILE CONFIG_FILE
#
# For each KEY=value line in EXAMPLE_FILE, checks if KEY= exists in
# CONFIG_FILE. If missing, appends the variable (with the preceding comment
# line from the example, if any) to the config file.
#
# Returns 0 always. Prints each newly added variable to stdout.
sync_customer_config() {
  local example="$1" config="$2"
  local added=0

  if [ ! -f "$example" ]; then
    echo "Warning: example config not found: $example"
    return 0
  fi
  if [ ! -f "$config" ]; then
    echo "Warning: customer config not found: $config"
    return 0
  fi

  # Ensure config ends with a newline (avoids appending on the same line)
  if [ -s "$config" ] && [ "$(tail -c1 "$config")" != "" ]; then
    echo "" >> "$config"
  fi

  local prev_line=""
  local in_section_header=false
  local section_header=""

  while IFS= read -r line || [ -n "$line" ]; do
    # Track section headers (lines starting with # ===)
    if [[ "$line" =~ ^#\ ===+ ]]; then
      in_section_header=true
      section_header="$line"
      prev_line="$line"
      continue
    fi

    # Track comment lines (potential variable descriptions)
    if [[ "$line" =~ ^# ]]; then
      if [ "$in_section_header" = true ]; then
        section_header="${section_header}"$'\n'"${line}"
      fi
      prev_line="$line"
      continue
    fi

    # Skip blank lines
    if [ -z "$line" ]; then
      in_section_header=false
      section_header=""
      prev_line=""
      continue
    fi

    # We have a non-comment, non-blank line - check if it's a variable assignment
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)= ]]; then
      local key="${BASH_REMATCH[1]}"
      in_section_header=false

      # Check if this key already exists in the customer config
      if ! grep -q "^${key}=" "$config"; then
        # Append comment + variable to config
        echo "" >> "$config"
        # Add the preceding comment line if it's descriptive (not a section header)
        if [ -n "$prev_line" ] && [[ "$prev_line" =~ ^# ]] && ! [[ "$prev_line" =~ ^#\ ===+ ]]; then
          echo "$prev_line" >> "$config"
        fi
        echo "$line" >> "$config"
        echo "  Added new variable: $key"
        added=$((added + 1))
      fi
    fi

    section_header=""
    prev_line="$line"
  done < "$example"

  if [ "$added" -gt 0 ]; then
    echo ""
    echo "Synced $added new variable(s) from template to customer-config.sh"
  fi

  return 0
}

# detect_example_file PROJECT_DIR CONFIG_FILE
#
# Returns the example template used to sync new variables into the active
# config. There is a single prod template.
detect_example_file() {
  local project_dir="$1" config="$2"

  echo "$project_dir/customer-config-prod.example.sh"
}
