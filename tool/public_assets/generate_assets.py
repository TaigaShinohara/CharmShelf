#!/usr/bin/env python3
"""Generate original public demo assets from geometry and synthesized waveforms.

Requires Pillow 10+ and FFmpeg. No recordings, external images, fonts or models.
The source and resulting first-party assets are distributed under the root MIT license.
"""
from pathlib import Path
import hashlib, json, math, subprocess, tempfile, wave
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SIZE = 768


def canvas(top, bottom):
    im = Image.new("RGB", (SIZE, SIZE))
    draw = ImageDraw.Draw(im)
    for y in range(SIZE):
        a = y / (SIZE - 1)
        draw.line((0, y, SIZE, y), fill=tuple(round(x * (1-a) + z * a) for x,z in zip(top,bottom)))
    return im


def icon():
    im = canvas((60, 92, 154), (103, 135, 173))
    d = ImageDraw.Draw(im)
    for x,y,w,h,c in [(158,210,126,292,"#D6E7E3"),(306,162,132,340,"#ECD9A9"),(460,258,138,244,"#B7CEDF")]:
        d.rounded_rectangle((x,y,x+w,y+h),24,fill=c)
        d.line((x+28,y+36,x+w-28,y+36),fill="#53718D",width=8)
    d.rounded_rectangle((108,530,660,562),16,fill="#FAF8F1")
    star=[]
    for i in range(10):
        a=-math.pi/2+i*math.pi/5
        rad=57 if i%2==0 else 25
        star.append((540+math.cos(a)*rad,170+math.sin(a)*rad))
    d.polygon(star,fill="#FAE7B4")
    return im


def scene(kind):
    colors=[((183,212,224),(239,221,187)),((80,140,173),(220,224,202)),((121,103,158),(237,179,143)),((37,53,91),(96,118,155)),((210,223,205),(245,234,207)),((24,41,73),(70,85,126)),((40,65,93),(131,158,167))]
    im=canvas(*colors[kind]); d=ImageDraw.Draw(im)
    if kind in (0,1,2):
        d.ellipse((490,100,604,214),fill="#F8E0A3")
        for i,c in enumerate(["#91ACAC","#668E97","#436C80"]):
            y=380+i*95
            d.polygon([(0,768),(0,y+80),(180,y-45),(380,y+30),(580,y-80),(768,y),(768,768)],fill=c)
        for i in range(5): d.arc((70+i*120,570,245+i*120,655),0,165,fill="#C4D9D8",width=4)
    elif kind==4:
        for x,h in [(170,270),(350,380),(560,300)]:
            d.line((x,580,x,580-h),fill="#4D766B",width=8)
            for off in range(3):
                y=500-off*75
                d.ellipse((x-88,y-55,x+4,y-2),fill="#789A7A")
                d.ellipse((x-4,y-105,x+80,y-52),fill="#4E8073")
            d.rounded_rectangle((x-72,585,x+72,690),20,fill="#C59D7D")
    else:
        for i in range(75):
            x=(i*127+45)%SIZE; y=(i*89+33)%470
            d.ellipse((x,y,x+3+(i%3),y+3+(i%3)),fill="#EBE5CC")
        d.ellipse((525,100,625,200),fill="#F3E5B9")
        d.polygon([(0,768),(0,600),(210,490),(400,610),(590,470),(768,590),(768,768)],fill="#243D53")
        d.rounded_rectangle((180,475,590,695),18,fill="#BFC9BF")
        d.rectangle((225,510,545,650),fill="#4E6F81")
        for x in (325,435): d.line((x,510,x,650),fill="#BFC9BF",width=8)
        d.line((225,580,545,580),fill="#BFC9BF",width=8)
    return im


def save(im, relative):
    p=ROOT/relative;p.parent.mkdir(parents=True,exist_ok=True)
    im.save(p,format="PNG",optimize=True)
    return relative


def audio(relative, notes):
    p=ROOT/relative;p.parent.mkdir(parents=True,exist_ok=True)
    rate=44100; duration=12; data=bytearray()
    for n in range(rate*duration):
        t=n/rate; beat=int(t/0.75); phase=t%0.75
        f=notes[beat%len(notes)]
        envelope=(1-math.exp(-phase*22))*math.exp(-phase*4.5)
        chord=sum(math.sin(2*math.pi*f*ratio*t)/weight for ratio,weight in [(1,1),(1.5,3),(2,5)])
        v=int(7500*envelope*chord)
        data.extend(max(-32768,min(32767,v)).to_bytes(2,"little",signed=True))
    with tempfile.TemporaryDirectory() as tmp:
        wav=Path(tmp)/"tone.wav"
        with wave.open(str(wav),"wb") as stream:
            stream.setnchannels(1);stream.setsampwidth(2);stream.setframerate(rate);stream.writeframes(data)
        subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-y","-i",str(wav),"-map_metadata","-1","-codec:a","libmp3lame","-q:a","4",str(p)],check=True)
    return relative


def main():
    files=[]; brand=icon()
    for rel in ("assets/images/icon/icon.png","assets/images/icon/icon_debug.png","assets/images/splash/icon_move_poster.png"):
        files.append(save(brand,rel))
    names=["photo_book/spring_trip_morning.png","photo_book/spring_trip_coast.png","photo_book/spring_trip_evening.png","illustration_collection/moonlit_reader.png","illustration_collection/botanical_atelier.png","illustration_collection/starlight_observatory.png","music_album/night_focus_cover.png"]
    for i,name in enumerate(names): files.append(save(scene(i),"assets/images/samples/"+name))
    svg='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 768 768"><rect width="768" height="768" rx="160" fill="#5578A8"/><g fill="#F8EDD1"><rect x="154" y="220" width="130" height="290" rx="22"/><rect x="308" y="166" width="132" height="344" rx="22"/><rect x="464" y="270" width="136" height="240" rx="22"/><rect x="110" y="540" width="548" height="28" rx="14"/></g></svg>\n'
    for name in ("private_shelf_icon.svg","private_shelf_icon_catalogize.svg"):
        p=ROOT/"assets/images/icon"/name;p.write_text(svg);files.append(str(p.relative_to(ROOT)))
    # Match generated launcher icon dimensions in each platform's source tree.
    for base in ("android/app/src","ios/Runner/Assets.xcassets","macos/Runner/Assets.xcassets","web"):
        for p in sorted((ROOT/base).rglob("*.png")):
            if "ic_notification" in p.name: continue
            with Image.open(p) as old: size=old.size
            brand.resize(size,Image.Resampling.LANCZOS).save(p,format="PNG",optimize=True)
            files.append(str(p.relative_to(ROOT)))
    ico=ROOT/"windows/runner/resources/app_icon.ico"
    brand.save(ico, format="ICO", sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
    files.append(str(ico.relative_to(ROOT)))
    files.append(audio("assets/sounds/digital_shelf_life.mp3",[261.63,329.63,392,523.25,440,392,329.63,293.66]))
    files.append(audio("assets/sounds/suki_ga_totonou_tagshelf_pv.mp3",[220,293.66,349.23,440,523.25,440,349.23,293.66]))
    movie=ROOT/"assets/videos/icon_move.mp4"
    subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-y","-loop","1","-i",str(ROOT/"assets/images/splash/icon_move_poster.png"),"-t","3","-vf","scale=512:512,fade=t=in:st=0:d=0.4,fade=t=out:st=2.5:d=0.5","-r","24","-c:v","libx264","-pix_fmt","yuv420p","-map_metadata","-1","-movflags","+faststart",str(movie)],check=True)
    files.append(str(movie.relative_to(ROOT)))
    manifest={"generator":"tool/public_assets/generate_assets.py","license":"MIT","inputs":"Original geometry and synthesized sine waves; no external source media or recordings.","files":{name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in sorted(set(files))}}
    (ROOT/"tool/public_assets/manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("Generated original public assets:",len(manifest["files"]))

if __name__=="__main__":main()
