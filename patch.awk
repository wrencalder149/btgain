# MUSIC + HEADSET only. Every point +gain mB, never above cap.
# Strip CR so a self-closing tag is really at the end of the line.
function grab_point(line, rest, j, inner, comma) {
    p_ok = 0
    gsub(/\r/, "", line)
    if (index(line, "<point>") == 0) return
    rest = substr(line, index(line, "<point>") + 7)
    j = index(rest, "</point>")
    if (j == 0) return
    inner = substr(rest, 1, j - 1)
    gsub(/[ \t]/, "", inner)
    comma = index(inner, ",")
    if (comma == 0) return
    p_idx = substr(inner, 1, comma - 1) + 0
    p_mb = substr(inner, comma + 1) + 0
    p_ok = 1
}
function ref_of(tag, k, rest, q) {
    k = index(tag, "ref=\"")
    if (k == 0) return ""
    rest = substr(tag, k + 5)
    q = index(rest, "\"")
    if (q == 0) return ""
    return substr(rest, 1, q - 1)
}
function is_music_headset(tag) {
    if (index(tag, "stream=\"AUDIO_STREAM_MUSIC\"") == 0) return 0
    if (index(tag, "deviceCategory=\"DEVICE_CATEGORY_HEADSET\"") == 0) return 0
    return 1
}
function boost_mb(mb) {
    mb = mb + gain
    if (mb > cap) mb = cap
    return mb
}
function emit_stored(name, n, i, mb, idx) {
    n = split(refs[name], arr, " ")
    for (i = 1; i <= n; i++) {
        split(arr[i], kv, ",")
        idx = kv[1] + 0
        mb = boost_mb(kv[2] + 0)
        if (printing) print "        <point>" idx "," mb "</point>"
        did = did + 1
    }
}
{
    gsub(/\r/, "")
}
FILENAME != lastfile {
    lastfile = FILENAME
    printing = (FILENAME == target)
    inref = 0
    invol = 0
    acc = ""
    boosting = 0
}
/<reference[ \t]/ && index($0, "name=\"") > 0 {
    inref = 1
    rest = substr($0, index($0, "name=\"") + 6)
    rname = substr(rest, 1, index(rest, "\"") - 1)
    rpts = ""
    if (printing) print
    next
}
inref {
    grab_point($0)
    if (p_ok) {
        if (rpts != "") rpts = rpts " "
        rpts = rpts p_idx "," p_mb
    }
    if (index($0, "</reference>") > 0) {
        refs[rname] = rpts
        inref = 0
    }
    if (printing) print
    next
}
printing && invol == 0 && index($0, "<volume") > 0 {
    acc = $0
    if (index(acc, ">") == 0) { invol = 1; next }
}
printing && invol == 1 {
    acc = acc " " $0
    if (index($0, ">") == 0) next
    invol = 0
    $0 = acc
    acc = ""
}
printing && index($0, "<volume") > 0 && is_music_headset($0) {
    name = ref_of($0)
    if (name != "") {
        if (refs[name] == "") {
            missed = missed + 1
            print $0
            next
        }
        tag = $0
        sub(/[ \t]*ref="[^"]*"/, "", tag)
        sub(/\/[ \t]*>$/, ">", tag)
        if (index(tag, "/>") > 0) {
            missed = missed + 1
            print $0
            next
        }
        print tag
        emit_stored(name)
        if (index(tag, "</volume>") == 0) print "    </volume>"
        print "    <!-- btgain-mark -->"
        next
    }
    if (index($0, "/>") > 0) {
        missed = missed + 1
        print $0
        next
    }
    print $0
    boosting = 1
    np = 0
    next
}
printing && boosting {
    grab_point($0)
    if (p_ok) {
        np++
        pi[np] = p_idx
        pm[np] = p_mb
        next
    }
    if (index($0, "</volume>") > 0) {
        for (i = 1; i <= np; i++) {
            print "        <point>" pi[i] "," boost_mb(pm[i]) "</point>"
            did = did + 1
        }
        print "    </volume>"
        print "    <!-- btgain-mark -->"
        boosting = 0
        np = 0
        next
    }
    next
}
printing { print }
END {
    printf "%d %d\n", did + 0, missed + 0 > report
}
