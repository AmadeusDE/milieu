#!/bin/sh

# Targets to audit
targets="./build.sh ./check.sh ./clean.sh script/c++ script/cc script/col script/cpp script/g++ script/gcc script/milieu-sync script/nroff"

# Pre-flight check for tools
has_sc=$(command -v shellcheck)
has_cb=$(command -v checkbashisms)

if [ -z "$has_sc" ] && [ -z "$has_cb" ]; then
    echo "Error: Neither 'shellcheck' nor 'checkbashisms' were found."
    echo "Please install at least one to audit your scripts."
    exit 1
fi

for script in $targets; do
    if [ -f "$script" ]; then
        echo "=== Auditing: $script ==="
        
        # Run ShellCheck if present
        if [ -n "$has_sc" ]; then
            shellcheck "$script"
        fi

        # Run checkbashisms if present
        if [ -n "$has_cb" ]; then
            checkbashisms -f "$script"
        fi
    else
        echo "Skipped: $script (file not found)"
    fi
done