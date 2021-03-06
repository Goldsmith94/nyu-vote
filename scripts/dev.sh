#!/bin/bash

# Starts the code
# Mounts this directory inside the image

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ENV_ARGS=""

if [ -e $DIR/../config ]; then
  # Read environment args from config file
  while read line; do
    ENV_ARGS="$ENV_ARGS -e $line"
  done < $DIR/../config

  # Strip the first whitespace away
  ENV_ARGS=${ENV_ARGS:1}
fi

docker run -i -t $ENV_ARGS --rm --name nyu-vote -p 3000:3000 -v $DIR/../:/srv/nyu-vote/ hackad/nyu-vote bash
