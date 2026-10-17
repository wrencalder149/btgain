#!/system/bin/sh
ui_print "- 藍牙耳機增益"
ui_print "- 音樂走耳機時整段 +12 dB"
ui_print "- 關掉藍牙絕對音量，否則曲線不會進耳機"
ui_print "- 不改喇叭、不改聽筒"

cleanup() {
  rm -f "$MODPATH/patch.awk"
}
trap cleanup EXIT

GAIN=1200
CAP=1200

mirror=""
for base in "$MAGISKTMP/.magisk/mirror" "$MAGISKTMP/mirror"; do
  if [ -n "$base" ] && [ -d "$base/vendor" ]; then
    mirror="$base"
    break
  fi
done

pick() {
  rel="$1"
  if [ -n "$mirror" ] && [ -f "$mirror/$rel" ]; then
    echo "$mirror/$rel"
    return 0
  fi
  if [ -f "/$rel" ]; then
    echo "/$rel"
    return 0
  fi
  return 1
}

legacy_ok=0

for cand in \
  vendor/etc/audio_policy_volumes.xml \
  vendor/etc/audio/audio_policy_volumes.xml \
  system/etc/audio_policy_volumes.xml
do
  got="$(pick "$cand")" || continue
  if ! grep -q 'stream="AUDIO_STREAM_MUSIC"' "$got"; then
    continue
  fi
  if ! grep -q 'DEVICE_CATEGORY_HEADSET' "$got"; then
    continue
  fi
  dir="$(dirname "$got")"
  tables=""
  if [ -f "$dir/default_volume_tables.xml" ]; then
    tables="$dir/default_volume_tables.xml"
  fi
  out="$TMPDIR/btgain-volumes.xml"
  report="$TMPDIR/btgain-report"
  if [ -n "$tables" ]; then
    awk -f "$MODPATH/patch.awk" -v gain="$GAIN" -v cap="$CAP" -v target="$got" -v report="$report" \
      "$tables" "$got" > "$out" || continue
  else
    awk -f "$MODPATH/patch.awk" -v gain="$GAIN" -v cap="$CAP" -v target="$got" -v report="$report" \
      "$got" > "$out" || continue
  fi
  read did missed < "$report"
  if [ -z "$did" ] || [ "$did" -lt 1 ]; then
    ui_print "! 沒有改到音樂耳機曲線"
    continue
  fi
  if [ -n "$missed" ] && [ "$missed" -gt 0 ]; then
    ui_print "! 標籤沒打開，這次不安裝壞掉的音量表"
    continue
  fi
  if ! grep -q 'btgain-mark' "$out"; then
    continue
  fi
  if grep -q 'DEVICE_CATEGORY_HEADSET"/>' "$out"; then
    ui_print "! 耳機標籤仍是自閉合，不安裝"
    continue
  fi
  dest="$MODPATH/system/$cand"
  mkdir -p "$(dirname "$dest")"
  cp "$out" "$dest"
  set_perm "$dest" 0 0 0644
  ui_print "- 音樂耳機改了 $did 個點"
  ui_print "- 路徑 /$cand"
  legacy_ok=1
  break
done

if [ "$legacy_ok" -eq 0 ]; then
  ui_print "! 找不到可改的音量表，這次沒有加增益"
else
  ui_print "- 重開機後，把藍牙耳機重新連一次"
fi
set_perm "$MODPATH/service.sh" 0 0 0755
exit 0
