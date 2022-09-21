
#!/usr/bin/env bash

echo "Listning on default mic"
# rec -r16k -c1 -esigned -traw - | docker run -i --net=host -v models:/dir tiro-speech-client --streaming - /dir/config.pbtxt 0.0.0.0:50051

rec -q -r16k -c1 -esigned -traw - | ../tsc-image/tiro_speech_client --streaming /dev/stdin models/config.pbtxt 0.0.0.0:50051

# rec -r16k -c1 -esigned -traw - | docker run -i --net=host -v models:/dir tiro-speech-client --streaming - /dir/config.pbtxt 0.0.0.0:50051
