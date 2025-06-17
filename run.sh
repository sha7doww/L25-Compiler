#!/bin/bash
set -e

# Function: print usage and exit
usage() {
  echo "Usage: $0 <input.l25> -o <output.pcode> [-d]"
  echo
  echo "  <input.l25>           Source file to preprocess and compile"
  echo "  -o <output.pcode>     Path to write the generated pcode"
  echo "  -d                    Use debug interpreter (interpreterd) instead of release (interpreter)"
  exit 1
}

# Parse arguments
DEBUG=false
INPUT=""
PCODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d)
      DEBUG=true
      shift
      ;;
    -o)
      PCODE="$2"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      usage
      ;;
    *)
      if [[ -z "$INPUT" ]]; then
        INPUT="$1"
        shift
      else
        echo "Unexpected argument: $1"
        usage
      fi
      ;;
  esac
done

# Ensure required arguments are set
if [[ -z "$INPUT" || -z "$PCODE" ]]; then
  usage
fi

# Run steps
build/compiler     < "$INPUT"   > "$PCODE"


build/interpreter  "$PCODE"

