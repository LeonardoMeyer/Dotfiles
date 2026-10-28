#!/usr/bin/env python3
# casts my screen to tvs. chromecast/google tv over mdns, dlna tvs over ssdp
# usage: cast.py scan | start cast|dlna <target> <name> region|window|screen | stop
# just needs wf-recorder and ffmpeg, didn't want pip stuff

import json, os, re, shutil, signal, socket, ssl, struct, subprocess, sys, tempfile, threading, time
import urllib.parse, urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from xml.etree import ElementTree as ET
from xml.sax.saxutils import escape

RUN = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
STATE = os.path.join(RUN, "cast-state")


def sh(cmd, inp=None):
    try:
        return subprocess.run(cmd, input=inp, capture_output=True, text=True, timeout=60).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def note(title, body=""):
    subprocess.run(["notify-send", "-a", "Cast", "-i", "video-display", title, body])


def state(s):
    with open(STATE + ".tmp", "w") as f:
        f.write(json.dumps(s) if s else "")
    os.replace(STATE + ".tmp", STATE)


def chromecasts():
    found = {}
    for line in sh(["avahi-browse", "-rtp", "_googlecast._tcp"]).splitlines():
        f = line.split(";", 9)
        if len(f) < 10 or f[0] != "=" or f[2] != "IPv4":
            continue
        txt = dict(t.split("=", 1) for t in re.findall(r'"([^"]*)"', f[9]) if "=" in t)
        found[f[7]] = {"kind": "cast", "target": f"{f[7]}:{f[8]}", "name": txt.get("fn") or f[3]}
    return list(found.values())


def describe(loc):
    root = ET.fromstring(urllib.request.urlopen(loc, timeout=2).read())
    for e in root.iter():
        e.tag = e.tag.split("}")[-1]
    for sv in root.iter("service"):
        if "AVTransport" in (sv.findtext("serviceType") or ""):
            base = root.findtext("URLBase") or loc
            return {"kind": "dlna", "target": urllib.parse.urljoin(base, sv.findtext("controlURL") or ""),
                    "name": root.findtext(".//device/friendlyName") or urllib.parse.urlparse(loc).hostname}
    return None


def renderers():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
    s.settimeout(0.4)
    msg = ("M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\n"
           "ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n").encode()
    locs, end = set(), time.time() + 3
    try:
        for _ in range(2):
            s.sendto(msg, ("239.255.255.250", 1900))
        while time.time() < end:
            try:
                m = re.search(rb"(?im)^location:\s*(\S+)", s.recvfrom(4096)[0])
                if m:
                    locs.add(m.group(1).decode())
            except socket.timeout:
                pass
    except OSError:
        pass
    out = []
    for loc in locs:
        try:
            d = describe(loc)
            if d:
                out.append(d)
        except Exception:
            pass
    return out


def scan():
    res = {}
    jobs = [threading.Thread(target=lambda k=k, f=f: res.__setitem__(k, f())) for k, f in (("cast", chromecasts), ("dlna", renderers))]
    for j in jobs:
        j.start()
    for j in jobs:
        j.join()
    cast = res.get("cast", [])
    # android tvs show up twice, the cast one works better
    names = {c["name"] for c in cast}
    tvs = cast + [d for d in res.get("dlna", []) if d["name"] not in names]
    print(json.dumps(sorted(tvs, key=lambda t: t["name"].lower())))


def area(mode):
    mons = json.loads(sh(["hyprctl", "-j", "monitors"]) or "[]")
    if mode == "screen":
        o = sh(["slurp", "-o", "-f", "%o"]).strip() if len(mons) > 1 else (mons[0]["name"] if mons else "")
        return ["-o", o] if o else None
    if mode == "window":
        ws = [m["activeWorkspace"]["id"] for m in mons]
        boxes = [f"{c['at'][0]},{c['at'][1]} {c['size'][0]}x{c['size'][1]}"
                 for c in json.loads(sh(["hyprctl", "-j", "clients"]) or "[]") if c["mapped"] and c["workspace"]["id"] in ws]
        g = sh(["slurp", "-r"], "\n".join(boxes))
    else:
        g = sh(["slurp", "-d"])
    return ["-g", g.strip()] if g.strip() else None


# h264 yuv420p mpegts, only thing every tv i tried would play
def capture(args):
    cmd = ["wf-recorder", "-y", *args, "-c", "libx264", "-x", "yuv420p", "-r", "30", "-F", "scale=-2:1080",
           "-p", "preset=ultrafast", "-p", "tune=zerolatency", "-p", "g=15", "-m", "mpegts", "-f", "pipe:1"]
    sink = sh(["pactl", "get-default-sink"]).strip()
    if sink:
        cmd[2:2] = [f"--audio={sink}.monitor", "-C", "aac"]
    return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)


class Serve(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_HEAD(self):
        self.route(False)

    def do_GET(self):
        self.route(True)

    def head(self, ctype, extra=()):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache")
        for k, v in extra:
            self.send_header(k, v)
        self.end_headers()

    def route(self, body):
        srv, p = self.server, urllib.parse.urlparse(self.path).path
        if p == "/live.ts":
            self.head("video/mp2t", [("transferMode.dlna.org", "Streaming"),
                                     ("contentFeatures.dlna.org", "DLNA.ORG_OP=00;DLNA.ORG_CI=0;DLNA.ORG_FLAGS=01700000000000000000000000000000")])
            if body:
                srv.stream(self.wfile)
            return
        f = os.path.join(srv.dir, os.path.basename(p))
        if p.startswith("/hls/") and os.path.isfile(f):
            data = open(f, "rb").read()
            self.head("application/vnd.apple.mpegurl" if f.endswith(".m3u8") else "video/mp2t", [("Content-Length", str(len(data)))])
            if body:
                self.wfile.write(data)
            return
        self.send_error(404)


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, d, args):
        super().__init__(("0.0.0.0", 0), Serve)
        self.dir, self.args, self.procs = d, args, []
        self.watching, self.seen, self.idle = 0, False, time.time()

    # dlna tvs pull one live stream, every connection gets its own recorder
    def stream(self, out):
        rec = capture(self.args)
        self.procs.append(rec)
        self.watching += 1
        self.seen = True
        try:
            while chunk := rec.stdout.read1(65536):
                out.write(chunk)
        except OSError:
            pass
        finally:
            rec.kill()
            self.watching -= 1
            self.idle = time.time()


# chromecast talks protobuf over tls, small enough to do by hand

def varint(n):
    out = b""
    while True:
        b, n = n & 0x7F, n >> 7
        if not n:
            return out + bytes([b])
        out += bytes([b | 0x80])


def readvar(d, i):
    n = s = 0
    while True:
        b = d[i]
        i += 1
        n |= (b & 0x7F) << s
        s += 7
        if b < 0x80:
            return n, i


def unpb(d):
    i, f = 0, {}
    while i < len(d):
        key, i = readvar(d, i)
        if key & 7 == 0:
            f[key >> 3], i = readvar(d, i)
        elif key & 7 == 2:
            n, i = readvar(d, i)
            f[key >> 3], i = d[i:i + n], i + n
        else:
            break
    return f


CONN, BEAT = "urn:x-cast:com.google.cast.tp.connection", "urn:x-cast:com.google.cast.tp.heartbeat"
RECV, MEDIA = "urn:x-cast:com.google.cast.receiver", "urn:x-cast:com.google.cast.media"
PLAYER = "CC1AD845"  # default media receiver


class Chromecast:
    def __init__(self, host, port):
        ctx = ssl.create_default_context()
        ctx.check_hostname, ctx.verify_mode = False, ssl.CERT_NONE
        self.s = ctx.wrap_socket(socket.create_connection((host, port), timeout=10))

    def send(self, ns, msg, dest="receiver-0"):
        body = json.dumps(msg).encode()
        d = b"".join([varint(1 << 3), varint(0)] +
                     [varint(n << 3 | 2) + varint(len(v)) + v for n, v in ((2, b"sender-0"), (3, dest.encode()), (4, ns.encode()))] +
                     [varint(5 << 3), varint(0), varint(6 << 3 | 2), varint(len(body)), body])
        self.s.sendall(struct.pack(">I", len(d)) + d)

    def exact(self, n):
        b = b""
        while len(b) < n:
            c = self.s.recv(n - len(b))
            if not c:
                raise ConnectionError("tv closed the connection")
            b += c
        return b

    def recv(self):
        f = unpb(self.exact(struct.unpack(">I", self.exact(4))[0]))
        ns, msg = f.get(4, b"").decode(), json.loads(f.get(6, b"{}") or b"{}")
        if ns == BEAT and msg.get("type") == "PING":
            self.send(BEAT, {"type": "PONG"}, "receiver-0")
        return ns, msg

    def app(self, msg):
        if msg.get("type") != "RECEIVER_STATUS":
            return None
        return next((a for a in msg.get("status", {}).get("applications", []) if a.get("appId") == PLAYER), False)


# tv opens its player while the stream warms up, saves a couple seconds
def chromecast(target, url, ready):
    host, port = target.rsplit(":", 1)
    cc = Chromecast(host, int(port))
    cc.send(CONN, {"type": "CONNECT"})
    cc.send(RECV, {"type": "LAUNCH", "appId": PLAYER, "requestId": 1})
    app, end = None, time.time() + 20
    while not app:
        if time.time() > end:
            raise TimeoutError("tv didn't open the player")
        app = cc.app(cc.recv()[1])
    ready()
    tid = app["transportId"]
    cc.send(CONN, {"type": "CONNECT"}, tid)
    cc.send(MEDIA, {"type": "LOAD", "requestId": 2, "autoplay": True,
                    "media": {"contentId": url, "contentType": "application/x-mpegURL", "streamType": "LIVE"}}, tid)
    return cc, app["sessionId"]


def watch_chromecast(cc, live):
    cc.s.settimeout(5)
    while True:
        try:
            ns, msg = cc.recv()
        except socket.timeout:
            cc.send(BEAT, {"type": "PING"})
            continue
        if cc.app(msg) is False:
            return  # someone switched the tv to something else
        t = msg.get("type")
        if t in ("LOAD_FAILED", "LOAD_CANCELLED"):
            raise RuntimeError("tv couldn't play the stream")
        if t == "MEDIA_STATUS":
            if any(s.get("playerState") == "PLAYING" for s in msg.get("status", [])):
                live()
            if any(s.get("idleReason") in ("ERROR", "CANCELLED") for s in msg.get("status", [])):
                return


def soap(url, action, args=""):
    body = ('<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
            's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body>'
            f'<u:{action} xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID>{args}</u:{action}>'
            '</s:Body></s:Envelope>')
    req = urllib.request.Request(url, body.encode(), {"Content-Type": 'text/xml; charset="utf-8"',
                                                      "SOAPAction": f'"urn:schemas-upnp-org:service:AVTransport:1#{action}"'})
    urllib.request.urlopen(req, timeout=8).read()


def dlna(target, url):
    didl = ('<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" '
            'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"><item id="0" parentID="-1" restricted="1">'
            '<dc:title>Screen</dc:title><upnp:class>object.item.videoItem</upnp:class>'
            f'<res protocolInfo="http-get:*:video/mp2t:*">{escape(url)}</res></item></DIDL-Lite>')
    try:
        soap(target, "Stop")
    except Exception:
        pass
    soap(target, "SetAVTransportURI", f"<CurrentURI>{escape(url)}</CurrentURI><CurrentURIMetaData>{escape(didl)}</CurrentURIMetaData>")
    soap(target, "Play", "<Speed>1</Speed>")


def local_ip(host):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect((host, 9))
        return s.getsockname()[0]
    finally:
        s.close()


def stop():
    try:
        pid = json.load(open(STATE)).get("pid", 0)
        if pid and pid != os.getpid():
            os.kill(pid, signal.SIGTERM)
    except (OSError, ValueError):
        pass


def start(kind, target, name, mode):
    for tool in ("wf-recorder", "ffmpeg"):
        if not shutil.which(tool):
            return note("Can't cast", tool + " isn't installed")
    args = area(mode)
    if not args:
        return
    stop()
    signal.signal(signal.SIGTERM, lambda *a: sys.exit(0))
    signal.signal(signal.SIGINT, lambda *a: sys.exit(0))
    began = int(time.time())
    state({"pid": os.getpid(), "name": name, "started": 0})
    shown = []
    def live():
        if not shown:
            shown.append(1)
            state({"pid": os.getpid(), "name": name, "started": began})

    d = tempfile.mkdtemp(prefix="cast-", dir=RUN)
    srv = Server(d, args)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    host = target.rsplit(":", 1)[0] if kind == "cast" else urllib.parse.urlparse(target).hostname
    base = f"http://{local_ip(host)}:{srv.server_address[1]}"
    cc = session = None
    try:
        if kind == "cast":
            # chromecast only takes live video as hls
            rec = capture(args)
            seg = subprocess.Popen(["ffmpeg", "-loglevel", "error", "-i", "pipe:0", "-c", "copy", "-f", "hls", "-hls_time", "0.5",
                                    "-hls_list_size", "4", "-hls_flags", "delete_segments+omit_endlist", os.path.join(d, "index.m3u8")],
                                   stdin=rec.stdout)
            rec.stdout.close()
            srv.procs += [rec, seg]
            def ready():
                end = time.time() + 15
                while not os.path.exists(os.path.join(d, "index.m3u8")):
                    if time.time() > end or seg.poll() is not None:
                        raise RuntimeError("screen capture didn't start")
                    time.sleep(0.05)
            cc, session = chromecast(target, base + "/hls/index.m3u8", ready)
            watch_chromecast(cc, live)
        else:
            dlna(target, base + "/live.ts")
            # done once the tv hangs up and doesn't come back
            end = time.time() + 20
            while srv.watching or (srv.seen and time.time() - srv.idle < 10) or (not srv.seen and time.time() < end):
                if srv.watching:
                    live()
                time.sleep(1)
            if not srv.seen:
                raise RuntimeError("tv never asked for the stream")
    except SystemExit:
        pass
    except Exception as e:
        note("Couldn't cast to " + name, str(e))
    finally:
        try:
            if cc:
                cc.send(RECV, {"type": "STOP", "sessionId": session, "requestId": 3})
            elif kind == "dlna":
                soap(target, "Stop")
        except Exception:
            pass
        for p in srv.procs:
            p.kill()
        srv.shutdown()
        shutil.rmtree(d, ignore_errors=True)
        state(None)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["scan"]:
        scan()
    elif a[:1] == ["start"] and len(a) == 5:
        start(*a[1:])
    elif a[:1] == ["stop"]:
        stop()
    else:
        sys.exit("usage: cast.py scan | start cast|dlna <target> <name> region|window|screen | stop")
