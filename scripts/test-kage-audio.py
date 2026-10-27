#!/usr/bin/env python3
"""Validate a packaged Kage audio pipeline with synthetic stereo signals only."""
import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys


def run(args, timeout=120):
    return subprocess.run([str(x) for x in args], check=True, capture_output=True, timeout=timeout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    app, root = args.app.resolve(), args.output.resolve()
    if root.exists() and any(root.iterdir()):
        raise SystemExit('Choose an empty audio QA output directory.')
    root.mkdir(parents=True, exist_ok=True)
    binary = app / 'Contents/MacOS/Kage'
    ffmpeg = app / 'Contents/Resources/Tools/ffmpeg'
    ffprobe = app / 'Contents/Resources/Tools/ffprobe'
    for path in (binary, ffmpeg, ffprobe):
        if not path.is_file(): raise SystemExit('A complete packaged Kage app is required.')
    checks, rows = [], []

    def check(condition, label):
        if not condition: raise AssertionError(label)
        checks.append(label)

    def probe(path):
        data = json.loads(run([ffprobe, '-v', 'error', '-show_streams', '-show_format', '-of', 'json', path]).stdout)
        audio = next(s for s in data['streams'] if s['codec_type'] == 'audio')
        return data, audio

    def samples(path, channels=2):
        data = run([ffmpeg, '-v', 'error', '-nostdin', '-i', path, '-map', '0:a:0', '-ar', '48000', '-ac', str(channels), '-f', 'f32le', '-']).stdout
        values = array.array('f'); values.frombytes(data)
        if sys.byteorder != 'little': values.byteswap()
        return [values[i::channels] for i in range(channels)]

    def rms(values):
        return math.sqrt(sum(v*v for v in values) / max(1, len(values)))

    def frequency(values):
        central = values[24000:-24000]
        crossings = sum(a <= 0 < b for a, b in zip(central, central[1:]))
        return crossings * 48000 / max(1, len(central)-1)

    def amplitude(values, hz):
        part = values[48000:96000]
        scale = 2 * math.pi * hz / 48000
        real = sum(v * math.cos(scale*i) for i, v in enumerate(part))
        imag = sum(v * math.sin(scale*i) for i, v in enumerate(part))
        return 2 * math.hypot(real, imag) / max(1, len(part))

    def operation(command, name, paths, folder, **options):
        folder.mkdir(exist_ok=True)
        options.update(outputDirectory=str(folder), revealInFinder=False)
        result = run([binary, command, name, *paths, '--json', '--options', json.dumps(options)])
        return [Path(p) for p in json.loads(result.stdout)]

    def save(error=None):
        result = {'product': 'Kage', 'scope': 'Packaged offline audio exports with generated tones; no user files or device listening',
                  'passed': len(checks), 'checks': checks, 'formats': rows, 'error': error}
        (root / 'audio-qa.json').write_text(json.dumps(result, indent=2) + '\n')

    try:
        source = root / 'Stereo test — Şişli.wav'
        run([ffmpeg, '-v', 'error', '-nostdin', '-n', '-f', 'lavfi', '-i',
             'aevalsrc=0.12*sin(2*PI*440*t)|0.08*sin(2*PI*880*t):s=48000:d=6',
             '-c:a', 'pcm_s16le', '-metadata', 'title=Kage synthetic audio', '-metadata', 'artist=Local QA', source])
        original = hashlib.sha256(source.read_bytes()).hexdigest()
        catalog = json.loads(run([binary, 'catalog']).stdout)
        targets = catalog['conversionMatrix']['wav']
        check(set(targets) == {'mp3','m4a','flac','ogg','opus','aiff','wma'}, 'Catalog exposes the expected seven WAV conversion targets')
        produced = {}
        for ext in ['wav', *targets]:
            output = source if ext == 'wav' else operation('convert', ext, [source], root / ('format-' + ext))[0]
            data, audio = probe(output)
            duration = float(data['format']['duration'])
            check(audio['channels'] == 2 and int(audio['sample_rate']) == 48000 and abs(duration-6) < 0.17,
                  ext.upper() + ': stereo, 48 kHz and six-second duration')
            left, right = samples(output)
            lf, rf = frequency(left), frequency(right)
            lr, rr = rms(left[24000:-24000]), rms(right[24000:-24000])
            check(abs(lf-440) < 3 and abs(rf-880) < 3 and 0.04 < lr < 0.14 and 0.025 < rr < 0.10,
                  ext.upper() + ': distinct audible left/right tones survive; no channel swap or silence')
            check(all(math.isfinite(v) and abs(v) <= 1.001 for channel in (left,right) for v in channel),
                  ext.upper() + ': decoded samples are finite and unclipped')
            rows.append({'format':ext,'codec':audio['codec_name'],'channels':audio['channels'],
                         'sampleRate':int(audio['sample_rate']),'duration':duration,
                         'leftHz':round(lf,2),'rightHz':round(rf,2),'leftRMS':round(lr,5),'rightRMS':round(rr,5)})
            produced[ext] = output
            if ext != 'wav':
                restored = operation('convert', 'wav', [output], root / ('reimport-' + ext))[0]
                restored_data, restored_audio = probe(restored)
                check(restored_audio['channels'] == 2 and abs(float(restored_data['format']['duration'])-6)<0.17,
                      ext.upper() + ': reimports through Kage and exports playable WAV')
        trimmed = operation('tool','trimAudio',[source],root/'trim',start=1,end=3)[0]
        data, audio = probe(trimmed)
        check(abs(float(data['format']['duration'])-2)<0.02 and audio['channels']==2, 'Audio trim exports exactly the selected two seconds')
        muted = operation('tool','audioChannels',[source],root/'mute-left',channels=2,leftVolume=0,rightVolume=1)[0]
        left, right = samples(muted)
        check(rms(left)<0.0001 and rms(right)>0.025, 'Channel editing mutes only the selected left channel')
        mono = operation('tool','audioChannels',[source],root/'mono',channels=1)[0]
        data, audio = probe(mono); values = samples(mono,1)[0]
        check(audio['channels']==1 and amplitude(values,440)>0.04 and amplitude(values,880)>0.025,
              'Mono mix retains content from both source channels')
        normalized = operation('tool','normalizeAudio',[source],root/'normalize',targetLoudness=-16,truePeak=-1.5)[0]
        measurement = run([ffmpeg,'-hide_banner','-nostats','-i',normalized,'-af',
                           'loudnorm=I=-16:LRA=11:TP=-1.5:print_format=json','-f','null','-']).stderr.decode()
        loudness = json.loads(re.findall(r'\{\s*"input_i".*?\}', measurement, re.S)[-1])
        check(abs(float(loudness['input_i'])+16)<1.0 and float(loudness['input_tp'])<=-1.25,
              'Normalization reaches the chosen loudness and stays below the true-peak ceiling')
        clean = operation('tool','removeMetadata',[source],root/'metadata')[0]
        tags = probe(clean)[0]['format'].get('tags',{})
        check(not any(k.lower() in {'title','artist'} for k in tags), 'Audio metadata copy removes the synthetic title and artist')
        batch = operation('convert','flac',[source,produced['mp3']],root/'batch')
        check(len(batch)==2 and batch[0]!=batch[1] and all(probe(p)[1]['channels']==2 for p in batch),
              'Batch conversion publishes two independent playable outputs without filename collisions')
        broken = root / 'Malformed.wav'; broken.write_bytes(b'Not an audio container: synthetic rejection fixture')
        rejected = root / 'rejected'; rejected.mkdir()
        failure = subprocess.run([str(binary),'convert','mp3',str(broken),'--json','--options',
                                  json.dumps({'outputDirectory':str(rejected),'revealInFinder':False})],capture_output=True,timeout=20)
        check(failure.returncode != 0 and not list(rejected.iterdir()), 'Malformed audio fails without publishing an empty or partial output')
        check(hashlib.sha256(source.read_bytes()).hexdigest()==original, 'All audio operations preserve the original WAV byte for byte')
        check(not any(p.name.startswith('.nashi-') for p in root.rglob('*')), 'Successful audio exports leave no incomplete transaction directories')
        save(); print('PASS:',len(checks),'packaged audio checks across eight input/output formats')
    except Exception as error:
        save(str(error)); raise


if __name__ == '__main__': main()
