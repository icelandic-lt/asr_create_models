#!/usr/bin/env bash


model_dir=$1
port=$2
if [ $# -ne 2 ]; then
    echo "Usage: $0 <model_dir> <port>" 
    exit 1
fi

echo "Let's start the TSC server with docker. We expect that docker is installed."

echo "Checking if docker is installed..."
if ! command -v docker &> /dev/null
    echo "Docker found"
then
    echo "Docker could not be found"
fi

echo "Removing image if it exists..."
docker image rm -f tiro-speech-server

echo "Removing container if it exists..."
docker container rm -f tiro-speech-server

echo "Loading image..."
docker load -i /home/dem/Projects/tiro-speech-core/bazel-bin/tiro_speech_images.tar
# docker load -i ../tsc-image/tiro_speech_images.tar


dockerServerCmd="docker run --rm -i --name tiro-speech-server --net=host --mount type=bind,src=$model_dir/,target=/model tiro-speech-server --listen-address=0.0.0.0:${port} --log-level=DEBUG --kaldi-models=/model"

echo "Staring server with command: $dockerServerCmd"
$dockerServerCmd 

echo "Tiro Speech Core server started and is listning on port ${port}"

