#!/usr/bin/env bash
awk '
    function flush() {
        if (err != "" & err !~ /still in use at exit/) {
            print err
            found = 1
        }
    err = ""
    }

# Report the last err and hold onto the current one
/^(ERROR|SCRIPT ERROR)/ { flush(); err = $0; next }

# If the err is in addons/ then we skip it 
/^[[:space:]]/ { if (/\[0\] .*\(res:\/\/addons\//) err = ""; next }

{ flush() }
END { flush(); exit found }
'
