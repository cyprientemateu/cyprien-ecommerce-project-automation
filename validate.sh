#!/bin/bash

TAG_APPS="$1"

# Check if TAG_APPS is empty
if [ -z "$TAG_APPS" ]; then
    echo "Error: TAG_APPS is not set or is empty."
    exit 1
fi

# Check if TAG_APPS matches the pattern v1.0.0
if [[ ! "$TAG_APPS" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: TAG_APPS does not match the version pattern 'v1.0.0'. Value found: $TAG_APPS"
    exit 1
fi

echo "TAG_APPS is set, not empty, and matches the version pattern."
