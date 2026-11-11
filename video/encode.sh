# frames/ (render.mjs: 6 subframes per output frame at 33.3 fps)
#   → ../docs/assets/hero.mp4 (1200 px, H.264) + hero.webp (animated, README hero)
set -e
mkdir -p out ../docs/assets
# tmix averages the 6 subframes into one motion-blurred frame
BL="tmix=frames=6,select='eq(mod(n\,6)\,5)',setpts=N*3/100/TB"
command ffmpeg -hide_banner -loglevel error -y -framerate 200 -i frames/%05d.png -vf "$BL,scale=1200:-2:flags=lanczos" -fps_mode passthrough -video_track_timescale 100 -c:v libx264 -crf 16 -pix_fmt yuv420p -movflags +faststart ../docs/assets/hero.mp4
# WebP straight from the blurred frames (not from the MP4) to avoid double compression.
# Lossy animated WebP only redraws regions it thinks changed, so faded content and soft glows
# linger as blocky ghosts. Keyframes every 2–4 frames fix it (-kmin 4 -kmax 8 still left
# a blocky glow under the keycaps at this size). Check: decode composited frames, not the MP4.
rm -rf out/wf && mkdir -p out/wf
command ffmpeg -hide_banner -loglevel error -y -framerate 200 -i frames/%05d.png -vf "$BL,scale=1200:-2:flags=lanczos" -fps_mode passthrough out/wf/%04d.png
img2webp -loop 0 -lossy -q 85 -m 4 -kmin 2 -kmax 4 -d 30 out/wf/*.png -o ../docs/assets/hero.webp >/dev/null
ls -lh ../docs/assets/hero.*
