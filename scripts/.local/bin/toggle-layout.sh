#!/bin/bash
niri msg keyboard-layouts 2>/dev/null | grep '\*' | awk '{print $3}' | cut -c1-2 | tr '[:lower:]' '[:upper:]'
