#!/usr/bin/env python3


# Copyright 2022 Tiro ehf.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ASR client. Excepts a a

from multiprocessing import Pool

import os
from typing import Tuple, Iterator
import grpc
from tiro.speech.v1alpha import speech_pb2, speech_pb2_grpc
import wave


def parse_arguments():
    import argparse

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

    def supported_filetypes(
        fname: str,
    ) -> Tuple[bytes, int]:
        _, ext = os.path.splitext(fname)
        if ext not in (".wav", ".flac", ".mp3"):
            raise ValueError("Unsupported extension!")
        encoding = speech_pb2.RecognitionConfig.LINEAR16
        if ext == ".flac":
            encoding = speech_pb2.RecognitionConfig.FLAC
        elif ext == ".mp3":
            encoding = speech_pb2.RecognitionConfig.MP3
        return (fname, encoding)

    def str2bool(v: str) -> bool:
        if isinstance(v, bool):
            return v
        if v.lower() in ("yes", "true", "t", "y", "1"):
            return True
        elif v.lower() in ("no", "false", "f", "n", "0"):
            return False
        else:
            raise argparse.ArgumentTypeError("Boolean value expected.")

    parser.add_argument(
        "--server-url",
        "-c",
        default="0.0.0.0:50051",
        help="The ASR server. By default it connects to the open server hosted by Tiro",
    )
    parser.add_argument(
        "--channel_credentials",
        "-cc",
        default=None,
        help="Implement later",
    )
    parser.add_argument(
        "--audio_file",
        "-af",
        default=None,
        type=supported_filetypes,
        help="Path to the audiofile",
    )

    parser.add_argument(
        "--sample_rate",
        "-r",
        type=int,
        default=16000,
        help="Sample rate of audio_file in hertz",
    )
    parser.add_argument(
        "--timestamps",
        type=str2bool,
        default=True,
        help="Disable timestamp output on top result",
    )
    parser.add_argument(
        "--nbest",
        "-n",
        metavar="N",
        type=int,
        default=1,
        help="Return up to N best results",
    )
    parser.add_argument(
        "--punctuation",
        "-p",
        type=str2bool,
        default=True,
        help="Automatically punctuate the output [True/False]",
    )
    parser.add_argument(
        "--lang_codec",
        "-l",
        type=str,
        default="is-IS",
        help="Automatically punctuate the output [True/False]",
    )

    parser.add_argument(
        "--input",
        "-i",
        default=None,
        help="Input file to be transcribed. Contents of the file should be '<path-to-audiofile>\t<text>\n'",
    )

    parser.add_argument(
        "--output",
        "-o",
        default=None,
        help="Provide the path for the output file. ",
    )

    parser.add_argument(
        "--num_jobs",
        "-nj",
        default=4,
        help="Number of transcription jobs to run in parallel",
    )

    return parser.parse_args()


class recognize_client:
    def __init__(self, args) -> None:
        self.server_url = args.server_url
        self.sample_rate_hertz = args.sample_rate
        self.timestamps = args.timestamps
        self.automatic_punctuation = args.punctuation
        self.nbest = args.nbest
        self.lang_codec = args.lang_codec

        if args.channel_credentials:
            # todo: Setup a flag for a access token and open a gated connection
            # self.creds = grpc.composite_channel_credentials(
            #     grpc.ssl_channel_credentials(),
            #     access_token_call_credentials(channel_credentials)
            # )
            pass
        else:
            self.creds = grpc.ssl_channel_credentials()

        if self.server_url.split(":")[0] == "0.0.0.0":
            self.stub = speech_pb2_grpc.SpeechStub(
                grpc.insecure_channel(self.server_url)
            )
        else:
            self.stub = speech_pb2_grpc.SpeechStub(
                grpc.secure_channel(self.server_url, self.creds)
            )

    def stream_requests(
        self, audio_file, interim_results=False
    ) -> Iterator[speech_pb2.StreamingRecognizeRequest]:
        """
        Parses the stream request
        """
        try:
            with wave.open(audio_file, "rb") as wav_f:
                sample_rate_hertz = wav_f.getframerate()
                chunk_size_in_seconds = 0.5
                yield speech_pb2.StreamingRecognizeRequest(
                    streaming_config=speech_pb2.StreamingRecognitionConfig(
                        interim_results=interim_results,
                        config=speech_pb2.RecognitionConfig(
                            encoding=speech_pb2.RecognitionConfig.LINEAR16,
                            max_alternatives=self.nbest,
                            sample_rate_hertz=sample_rate_hertz,
                            language_code=self.lang_codec,
                            enable_word_time_offsets=self.timestamps,
                            enable_automatic_punctuation=self.automatic_punctuation,
                        ),
                    )
                )
                chunk_size_in_samples = int(sample_rate_hertz * chunk_size_in_seconds)
                while True:
                    chunk = wav_f.readframes(chunk_size_in_samples)
                    if not chunk:
                        break
                    yield speech_pb2.StreamingRecognizeRequest(
                        audio_content=chunk,
                    )
        except Exception as e:
            print(e)

    def stream(self, audio_file) -> None:
        """
        Recognize a stream of audio or a long audio file. Print to console the transcription.
        """
        responses = self.stub.StreamingRecognize(self.stream_requests(audio_file))
        for response in responses:
            for res in response.results:
                if res.is_final:
                    return res.alternatives[0].transcript


def run_stream(it):
    client = recognize_client(it[2])
    transcript = client.stream(it[0])
    return (it[1], transcript)


def main():
    args = parse_arguments()
    iterable = [[*x.rstrip().split(), args] for x in open(args.input, "r")]
    with Pool(processes=int(args.num_jobs)) as pool:
        res = pool.map(run_stream, iterable)
    with open(args.output, "w") as f_out:
        for file_id, transcript in res:
            f_out.write(f"{file_id}\t{transcript}\n")


if __name__ == "__main__":
    main()


# python3 src/recognize.py -i test_sets/althingi/data/dev_audio_segments -o test --server-url 0.0.0.0:50051
