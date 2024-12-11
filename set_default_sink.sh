#!/bin/sh

# Replace this with the actual name of your ProFX sink
SINK_NAME="playback.Adam_Speakers"

# Set the default sink
pw-cli set-default $SINK_NAME

# Move all playing streams to the new default sink
pw-play --all --sink=$SINK_NAME
