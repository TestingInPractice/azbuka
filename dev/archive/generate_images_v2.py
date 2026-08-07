#!/usr/bin/env python3
"""Generate 280×280 kid-friendly PNG illustrations for Азбука game."""
import os, math
from PIL import Image, ImageDraw

OUT = "/Users/halapinvv/azbuka-pwa/assets/images"
W, H, R = 280, 280, 20  # radius for rounded rect
CX, CY = W//2, H//2

colors = {
    "red": "#e53935", "dark_red": "#b71c1c",
    "pink": "#e91e63", "dark_pink": "#c2185b",
    "orange": "#ff8f00", "dark_orange": "#e65100",
    "yellow": "#FFD700", "dark_yellow": "#f9a825",
    "green": "#4caf50", "dark_green": "#2e7d32",
    "light_green": "#81c784",
    "blue": "#2196f3", "dark_blue": "#1565c0",
    "light_blue": "#42a5f5",
    "purple": "#9c27b0", "brown": "#795548",
    "grey": "#9e9e9e", "dark_grey": "#616161",
    "white": "#ffffff", "black": "#333333",
    "skin": "#ffcc80",
}

def rounded_rect(draw, xy, fill, r=15):
    x1, y1, x2, y2 = xy
    draw.rounded_rectangle(xy, r, fill=fill)

def ellipse(draw, xy, fill, outline="#333", width=3):
    draw.ellipse(xy, fill=fill, outline=outline, width=width)

def create_bg(bg="#f0f8ff"):
    img = Image.new("RGBA", (W, H), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle([2,2,W-2,H-2], R, fill=bg)
    return img, draw

def save(name, img):
    path = os.path.join(OUT, name + ".png")
    img.save(path, "PNG")
    print(f"  {name}.png")

# ─── 30 ILLUSTRATIONS ───────────────────────────────────────────────────────

def arbuz():
    img, d = create_bg("#fff8e1")
    # watermelon slice
    d.arc([28,28,252,252], 0, 180, fill="#333", width=40)
    d.arc([30,30,250,250], 0, 180, fill="#4caf50", width=34)
    d.arc([45,45,235,235], 0, 180, fill="#e53935", width=28)
    # seeds
    for (x,y) in [(90,180),(120,160),(150,175),(180,150),(140,200)]:
        d.ellipse([x-4,y-5,x+4,y+5], fill="#333")
    save("arbuz", img)

def banan():
    img, d = create_bg("#fffde7")
    d.arc([58,58,202,202], 210, 330, fill="#333", width=32)
    d.arc([60,60,200,200], 210, 330, fill="#FFD700", width=28)
    d.arc([68,72,192,192], 215, 325, fill="#fff176", width=20)
    d.point([65,95], fill="#795548")
    save("banan", img)

def cherepaha():
    img, d = create_bg("#e8f5e9")
    # shell
    d.ellipse([80,110,200,210], fill="#4caf50", outline="#333", width=3)
    d.ellipse([90,120,190,200], fill=None, outline="#2e7d32", width=2)
    d.line([140,110,140,210], fill="#2e7d32", width=2)
    d.line([80,160,200,160], fill="#2e7d32", width=2)
    d.line([95,130,185,190], fill="#2e7d32", width=1)
    d.line([185,130,95,190], fill="#2e7d32", width=1)
    # head
    d.ellipse([120,205,160,235], fill="#81c784", outline="#333", width=3)
    d.ellipse([130,218,138,226], fill="#333")
    d.ellipse([142,218,150,226], fill="#333")
    # legs
    for (x,y) in [(70,140),(210,140),(72,178),(208,178)]:
        d.ellipse([x-10,y-6,x+10,y+6], fill="#81c784", outline="#333", width=2)
    # tail
    d.line([75,155,55,150], fill="#81c784", width=3)
    save("cherepaha", img)

def cyplenok():
    img, d = create_bg("#fff8e1")
    d.ellipse([85,75,195,185], fill="#FFD700", outline="#333", width=3)
    d.ellipse([110,108,124,122], fill="#333")
    d.ellipse([156,108,170,122], fill="#333")
    d.ellipse([112,110,122,120], fill="#fff")
    d.ellipse([158,110,168,120], fill="#fff")
    d.polygon([140,125,128,140,152,140], fill="#ff8f00", outline="#333", width=2)
    # wings
    d.ellipse([72,130,100,175], fill="#ffcc02", outline="#333", width=2)
    d.ellipse([180,130,208,175], fill="#ffcc02", outline="#333", width=2)
    # crest
    d.line([120,78,108,68], fill="#ff7043", width=4)
    d.line([140,75,140,63], fill="#ff7043", width=4)
    d.line([160,78,172,68], fill="#ff7043", width=4)
    save("cyplenok", img)

def dom():
    img, d = create_bg("#e3f2fd")
    # roof
    d.polygon([25,135,140,35,255,135], fill="#e53935", outline="#333", width=3)
    # walls
    d.rectangle([40,135,240,245], fill="#ffcc80", outline="#333", width=3)
    # door
    d.rounded_rectangle([115,175,165,245], 15, fill="#5d4037", outline="#333", width=2)
    d.ellipse([155,208,162,215], fill="#FFD700")
    # windows
    d.rounded_rectangle([55,150,100,190], 8, fill="#bbdefb", outline="#1565c0", width=2)
    d.line([77,150,77,190], fill="#1565c0", width=2)
    d.line([55,170,100,170], fill="#1565c0", width=2)
    d.rounded_rectangle([180,150,225,190], 8, fill="#bbdefb", outline="#1565c0", width=2)
    d.line([202,150,202,190], fill="#1565c0", width=2)
    d.line([180,170,225,170], fill="#1565c0", width=2)
    # chimney
    d.rectangle([180,55,205,100], fill="#795548", outline="#333", width=2)
    save("dom", img)

def enot():
    img, d = create_bg("#f5f5f5")
    d.ellipse([85,120,195,200], fill="#9e9e9e", outline="#333", width=3)
    d.ellipse([100,70,180,150], fill="#9e9e9e", outline="#333", width=3)
    d.ellipse([105,95,175,125], fill="#424242")
    d.ellipse([115,100,132,117], fill="#fff")
    d.ellipse([148,100,165,117], fill="#fff")
    d.ellipse([118,103,130,115], fill="#333")
    d.ellipse([150,103,162,115], fill="#333")
    d.ellipse([133,118,147,128], fill="#333")
    # ears
    d.ellipse([88,62,118,92], fill="#9e9e9e", outline="#333", width=2)
    d.ellipse([92,66,114,88], fill="#e0e0e0")
    d.ellipse([162,62,192,92], fill="#9e9e9e", outline="#333", width=2)
    d.ellipse([166,66,188,88], fill="#e0e0e0")
    # tail
    d.ellipse([180,165,240,200], fill="#9e9e9e", outline="#333", width=3)
    d.ellipse([210,170,240,195], fill="#424242", outline="#333", width=2)
    # paws
    d.ellipse([95,185,120,205], fill="#616161")
    d.ellipse([160,185,185,205], fill="#616161")
    save("enot", img)

def yolka():
    img, d = create_bg("#e8f5e9")
    # tree triangles
    for i, (y1, xw) in enumerate([(60,80),(110,110),(165,140)]):
        d.polygon([CX, y1, CX-xw, y1+55, CX+xw, y1+55], fill="#4caf50", outline="#333", width=3)
    # trunk
    d.rectangle([125,220,155,245], fill="#795548", outline="#333", width=2)
    # decorations
    for (x,y,c,r) in [(100,100, "#e53935",5),(170,85,"#FFD700",5),(140,65,"#2196f3",6),
        (80,155,"#FFD700",5),(195,150,"#e53935",5),(120,140,"#9c27b0",5),
        (160,195,"#FFD700",5),(75,210,"#2196f3",4),(205,210,"#e53935",4)]:
        d.ellipse([x-r,y-r,x+r,y+r], fill=c, outline="#333", width=1)
    # star
    pts = []
    for i in range(10):
        a = math.radians(i*36 - 90)
        rad = 8 if i%2==0 else 4
        pts.append((CX+rad*math.cos(a), 40+rad*math.sin(a)))
    d.polygon(pts, fill="#FFD700", outline="#333", width=1)
    save("yolka", img)

def zhiraf():
    img, d = create_bg("#fffde7")
    # neck
    d.rectangle([120,50,148,170], fill="#ffcc02", outline="#333", width=3)
    # head
    d.ellipse([108,30,165,70], fill="#ffcc02", outline="#333", width=3)
    d.ellipse([118,40,128,50], fill="#333")
    d.ellipse([148,40,158,50], fill="#333")
    # ears
    d.ellipse([100,28,115,42], fill="#ff8f00")
    d.ellipse([158,28,173,42], fill="#ff8f00")
    # horns
    d.line([115,28,112,15], fill="#ff8f00", width=3)
    d.ellipse([108,10,116,18], fill="#795548")
    d.line([158,28,162,15], fill="#ff8f00", width=3)
    d.ellipse([157,10,165,18], fill="#795548")
    # body
    d.ellipse([100,150,200,210], fill="#ffcc02", outline="#333", width=3)
    # spots
    for (x,y) in [(130,155),(160,160),(170,180),(115,180)]:
        d.ellipse([x-5,y-4,x+5,y+4], fill="#ff8f00")
    # legs
    d.rectangle([110,200,130,255], fill="#ffcc02", outline="#333", width=2)
    d.rectangle([165,200,185,255], fill="#ffcc02", outline="#333", width=2)
    # tail
    d.line([195,165,215,150], fill="#ffcc02", width=4)
    d.ellipse([215,145,225,158], fill="#ff8f00")
    save("zhiraf", img)

def zebra():
    img, d = create_bg("#f5f5f5")
    d.ellipse([85,130,195,200], fill="#fff", outline="#333", width=3)
    for (x1,y1,x2,y2) in [(105,135,110,195),(125,132,130,198),(145,130,148,200),(165,133,168,198),(185,140,188,195)]:
        d.line([x1,y1,x2,y2], fill="#333", width=5)
    # neck
    d.polygon([95,150,90,100,120,100,125,150], fill="#fff", outline="#333", width=3)
    d.line([95,145,118,145], fill="#333", width=4)
    d.line([93,130,120,130], fill="#333", width=4)
    d.line([92,115,122,115], fill="#333", width=4)
    # head
    d.ellipse([78,82,128,120], fill="#fff", outline="#333", width=3)
    d.ellipse([88,95,98,105], fill="#333")
    d.ellipse([108,95,118,105], fill="#333")
    d.ellipse([85,108,120,118], fill="#e0e0e0")
    # ears
    d.ellipse([72,72,85,90], fill="#fff", outline="#333", width=2)
    d.ellipse([120,72,133,90], fill="#fff", outline="#333", width=2)
    # mane
    d.polygon([80,85,78,70,90,80,88,65,100,78], fill="#333")
    # legs
    for x in [105,172]:
        d.rectangle([x,195,x+15,250], fill="#fff", outline="#333", width=2)
        d.line([x+2,205,x+13,205], fill="#333", width=3)
        d.line([x+2,220,x+13,220], fill="#333", width=3)
        d.line([x+2,235,x+13,235], fill="#333", width=3)
    save("zebra", img)

def igla():
    img, d = create_bg("#fce4ec")
    d.polygon([130,30,136,30,142,10,124,10], fill="#e0e0e0", outline="#9e9e9e", width=2)
    d.rectangle([130,30,136,170], fill="#e0e0e0", outline="#9e9e9e", width=2)
    d.ellipse([130,168,136,174], fill="#9e9e9e")
    d.ellipse([130,18,136,26], fill="#fff", outline="#9e9e9e", width=1)
    # thread
    for i in range(20):
        t = i / 20
        x = 80 - 30 * math.sin(t * math.pi * 3)
        y = 30 + t * 160
    pts = []
    for i in range(51):
        t = i / 50
        x = 133 - 50 * math.sin(t * math.pi * 3) * (1-t*0.7)
        y = 22 + t * 200
        pts.append((x, y))
    for i in range(len(pts)-1):
        d.line([pts[i], pts[i+1]], fill="#e91e63", width=2)
    # spool
    d.rectangle([45,185,100,228], fill="#e91e63", outline="#333", width=2)
    d.rectangle([50,178,95,185], fill="#f48fb1", outline="#333", width=1)
    d.rectangle([50,228,95,235], fill="#f48fb1", outline="#333", width=1)
    d.line([72,185,72,228], fill="#c2185b", width=1)
    save("igla", img)

def yogurt():
    img, d = create_bg("#fffde7")
    d.polygon([85,55,195,55,180,230,100,230], fill="#fff9c4", outline="#f9a825", width=3)
    # lid
    d.rectangle([95,45,185,65], fill="#e53935", outline="#333", width=2)
    # label
    d.rounded_rectangle([100,75,180,175], 8, fill="#FFD700")
    d.text((130,95), "Й", fill="#e53935", font_size=28)
    # berries
    for (x,y) in [(110,185),(140,190),(165,185)]:
        d.ellipse([x-7,y-7,x+7,y+7], fill="#e91e63")
    save("yogurt", img)

def kit():
    img, d = create_bg("#e3f2fd")
    d.ellipse([60,125,205,195], fill="#42a5f5", outline="#1565c0", width=3)
    d.polygon([65,135,20,100,20,180], fill="#42a5f5", outline="#1565c0", width=3)
    d.ellipse([170,120,200,155], fill="#42a5f5")
    d.ellipse([185,148,198,162], fill="#fff")
    d.ellipse([188,150,196,160], fill="#333")
    d.arc([178,165,200,180], -30, 30, fill="#1565c0", width=2)
    d.ellipse([160,175,200,195], fill="#bbdefb")
    # water spout
    for (dx,dy) in [(-12,-20),(0,-25),(12,-20)]:
        d.line([140,125,140+dx,105+dy], fill="#90caf9", width=2)
    for (x,y) in [(128,103),(140,98),(152,103)]:
        d.ellipse([x-3,y-3,x+3,y+3], fill="#90caf9")
    save("kit", img)

def lisa():
    img, d = create_bg("#fff3e0")
    d.ellipse([95,130,185,195], fill="#ff7043", outline="#d84315", width=3)
    d.ellipse([105,135,170,185], fill="#fff")
    d.ellipse([85,72,160,142], fill="#ff7043", outline="#d84315", width=3)
    # ears
    for (dx,flip) in [(-25,1), (25,-1)]:
        d.polygon([140+dx*15,105,140+dx*25,60,140+dx*8,90], fill="#ff7043", outline="#d84315", width=2)
        d.polygon([140+dx*12,98,140+dx*20,68,140+dx*8,88], fill="#fff")
    # eyes
    d.ellipse([100,105,112,117], fill="#333")
    d.ellipse([142,105,154,117], fill="#333")
    d.ellipse([102,107,110,115], fill="#fff")
    d.ellipse([144,107,152,115], fill="#fff")
    d.ellipse([122,120,132,128], fill="#333")
    # tail
    d.ellipse([175,150,235,195], fill="#ff7043", outline="#d84315", width=3)
    d.ellipse([210,155,235,190], fill="#fff")
    # legs
    for x in [105,155]:
        d.rectangle([x,190,x+12,235], fill="#ff7043", outline="#d84315", width=2)
    save("lisa", img)

def malina():
    img, d = create_bg("#fce4ec")
    # leaves
    d.polygon([140,25,115,50,165,50], fill="#4caf50", outline="#2e7d32", width=2)
    d.line([140,28,140,55], fill="#2e7d32", width=2)
    # branches
    d.line([140,50,95,110], fill="#4caf50", width=2)
    d.line([140,50,175,105], fill="#4caf50", width=2)
    # raspberries
    for (cx,cy) in [(100,115),(120,108),(140,118),(110,130),(128,130),(150,112),(168,108),(180,118),(158,130),(175,130)]:
        d.ellipse([cx-7,cy-7,cx+7,cy+7], fill="#e91e63")
    for (cx,cy) in [(110,115),(130,118),(150,115),(170,118)]:
        d.ellipse([cx-8,cy-8,cx+8,cy+8], fill="#f06292")
    save("malina", img)

def nosorog():
    img, d = create_bg("#f5f5f5")
    d.ellipse([90,130,200,200], fill="#9e9e9e", outline="#616161", width=3)
    d.ellipse([55,108,130,168], fill="#9e9e9e", outline="#616161", width=3)
    d.polygon([60,125,58,80,78,122], fill="#e0e0e0", outline="#9e9e9e", width=2)
    d.polygon([65,115,64,95,74,113], fill="#fff")
    d.ellipse([85,128,96,140], fill="#333")
    d.ellipse([130,105,148,130], fill="#9e9e9e", outline="#616161", width=2)
    d.ellipse([134,110,144,125], fill="#e0e0e0")
    for x in [105,145,180]:
        d.rectangle([x,195,x+16,245], fill="#9e9e9e", outline="#616161", width=2)
    d.line([195,155,225,145], fill="#9e9e9e", width=4)
    save("nosorog", img)

def okun():
    img, d = create_bg("#e1f5fe")
    d.ellipse([75,120,200,180], fill="#4fc3f7", outline="#0288d1", width=3)
    d.polygon([80,130,30,100,30,180], fill="#4fc3f7", outline="#0288d1", width=3)
    d.polygon([95,110,120,75,150,105], fill="#81d4fa", outline="#0288d1", width=2)
    d.polygon([155,155,170,185,145,175], fill="#81d4fa", outline="#0288d1", width=2)
    d.ellipse([180,135,190,150], fill="#fff")
    d.ellipse([183,138,188,147], fill="#333")
    d.arc([195,145,210,160], -30, 30, fill="#0288d1", width=2)
    for (x,y) in [(120,135),(135,132),(150,135),(130,145),(145,145),(160,148)]:
        d.line([x-5,y,x+5,y], fill="#0288d1", width=1)
    d.line([135,120,135,172], fill="#01579b", width=2)
    d.line([155,122,155,170], fill="#01579b", width=2)
    save("okun", img)

def pingvin():
    img, d = create_bg("#e3f2fd")
    d.ellipse([95,105,185,225], fill="#333", outline="#111", width=3)
    d.ellipse([105,130,175,215], fill="#fff")
    d.ellipse([108,65,172,128], fill="#333", outline="#111", width=3)
    d.ellipse([118,75,130,90], fill="#fff")
    d.ellipse([150,75,162,90], fill="#fff")
    d.ellipse([121,78,128,88], fill="#333")
    d.ellipse([152,78,159,88], fill="#333")
    d.polygon([140,98,130,112,150,112], fill="#ff8f00", outline="#e65100", width=2)
    d.ellipse([75,128,100,185], fill="#333", outline="#111", width=2)
    d.ellipse([180,128,205,185], fill="#333", outline="#111", width=2)
    for x in [110,170]:
        d.ellipse([x-12,225,x+12,238], fill="#ff8f00", outline="#e65100", width=2)
    save("pingvin", img)

def raduga():
    img, d = create_bg("#e3f2fd")
    colors_arc = ["#e53935","#ff8f00","#FFD700","#4caf50","#2196f3","#9c27b0"]
    for i, c in enumerate(colors_arc):
        r = 180 - i * 8
        d.arc([CX-r,CY-80,CX+r,CY+100], 0, 180, fill=c, width=8)
    # clouds
    for (x,y,r1,r2) in [(45,165,35,25),(70,160,28,20),(220,165,35,25),(195,160,28,20)]:
        d.ellipse([x-r1,y-r2,x+r1,y+r2], fill="#fff", outline="#e0e0e0", width=2)
    # sun
    d.ellipse([220,35,255,70], fill="#FFD700")
    for i in range(8):
        a = math.radians(i*45)
        d.line([237+16*math.cos(a), 52+16*math.sin(a),
                237+24*math.cos(a), 52+24*math.sin(a)], fill="#FFD700", width=2)
    save("raduga", img)

def slon():
    img, d = create_bg("#eceff1")
    d.ellipse([90,125,200,200], fill="#b0bec5", outline="#78909c", width=3)
    d.ellipse([55,90,140,155], fill="#b0bec5", outline="#78909c", width=3)
    d.ellipse([95,95,145,150], fill="#cfd8dc", outline="#78909c", width=2)
    d.ellipse([70,105,82,118], fill="#333")
    d.ellipse([72,107,80,116], fill="#fff")
    d.arc([58,143,92,187], 180, 360, fill="#78909c", width=14)
    d.arc([60,145,90,185], 180, 360, fill="#b0bec5", width=10)
    # tusk
    d.pieslice([68,146,86,167], 180, 270, fill="#fff", outline="#78909c")
    for x in [115,150,180]:
        d.rectangle([x,195,x+18,245], fill="#b0bec5", outline="#78909c", width=2)
    d.line([195,155,220,145], fill="#b0bec5", width=4)
    save("slon", img)

def tigr():
    img, d = create_bg("#fffde7")
    d.ellipse([90,125,195,195], fill="#ffcc02", outline="#f9a825", width=3)
    # stripes
    for (x1,y1,x2,y2) in [(110,130,115,190),(135,128,140,192),(160,130,163,190),(182,135,185,188)]:
        d.line([x1,y1,x2,y2], fill="#333", width=4)
    d.ellipse([65,75,148,148], fill="#ffcc02", outline="#f9a825", width=3)
    # cheeks
    d.ellipse([68,105,98,125], fill="#fff")
    d.ellipse([115,105,145,125], fill="#fff")
    d.ellipse([78,100,90,112], fill="#333")
    d.ellipse([123,100,135,112], fill="#333")
    d.ellipse([78,102,88,110], fill="#fff")
    d.ellipse([123,102,133,110], fill="#fff")
    d.polygon([105,115,96,126,114,126], fill="#ff8f00")
    for (x,y) in [(58,72),(148,72)]:
        d.ellipse([x-8,y-8,x+8,y+8], fill="#ffcc02", outline="#f9a825", width=2)
        d.ellipse([x-4,y-4,x+4,y+4], fill="#fff")
    # stripes on head
    d.line([103,78,105,88], fill="#333", width=2)
    d.line([110,75,108,85], fill="#333", width=2)
    d.line([115,72,115,82], fill="#333", width=2)
    for x in [105,175]:
        d.rectangle([x,190,x+14,240], fill="#ffcc02", outline="#f9a825", width=2)
    d.ellipse([190,150,235,190], fill="#ffcc02", outline="#f9a825", width=3)
    d.line([215,163,223,155], fill="#333", width=4)
    save("tigr", img)

def ulitka():
    img, d = create_bg("#e8f5e9")
    d.ellipse([60,175,190,215], fill="#81c784", outline="#388e3c", width=3)
    d.ellipse([130,100,195,165], fill="#ffcc02", outline="#f9a825", width=3)
    d.arc([150,120,180,150], 0, 360, fill="#ff8f00", width=2)
    d.arc([140,110,170,140], 0, 360, fill="#ff8f00", width=1)
    for (x,y,dx,dy) in [(65,165, -15,-20),(78,165, -10,-25)]:
        d.line([x,y,x+dx,y+dy], fill="#81c784", width=3)
        d.ellipse([x+dx-3,y+dy-3,x+dx+3,y+dy+3], fill="#333")
    save("ulitka", img)

def flamingo():
    img, d = create_bg("#fce4ec")
    d.ellipse([100,120,165,175], fill="#f48fb1", outline="#d81b60", width=3)
    # neck
    pts = [(110,130),(95,100),(100,65)]
    for i in range(len(pts)-1):
        d.line([pts[i], pts[i+1]], fill="#f48fb1", width=10)
        d.line([pts[i], pts[i+1]], fill="#d81b60", width=3)
    d.ellipse([92,52,112,75], fill="#f48fb1", outline="#d81b60", width=2)
    d.ellipse([98,58,104,64], fill="#333")
    d.polygon([90,65,65,70,90,72], fill="#ff8f00", outline="#e65100", width=1)
    d.polygon([90,72,65,70,90,74], fill="#333")
    d.ellipse([105,137,145,170], fill="#f06292", outline="#d81b60", width=2)
    d.line([115,172,110,230], fill="#ff8f00", width=3)
    d.line([145,172,150,230], fill="#ff8f00", width=3)
    # tail
    d.line([160,130,178,118], fill="#f48fb1", width=4)
    d.line([162,135,185,130], fill="#f48fb1", width=4)
    save("flamingo", img)

def homyak():
    img, d = create_bg("#fffde7")
    d.ellipse([92,125,188,198], fill="#ffcc02", outline="#f9a825", width=3)
    d.ellipse([105,140,175,190], fill="#fff8e1")
    d.ellipse([100,70,180,150], fill="#ffcc02", outline="#f9a825", width=3)
    # cheeks
    d.ellipse([88,95,118,120], fill="#ff8a65")
    d.ellipse([162,95,192,120], fill="#ff8a65")
    d.ellipse([112,90,122,102], fill="#333")
    d.ellipse([158,90,168,102], fill="#333")
    d.ellipse([113,92,121,100], fill="#fff")
    d.ellipse([159,92,167,100], fill="#fff")
    d.ellipse([134,110,146,120], fill="#ff8a65")
    d.arc([130,124,150,130], 0, 180, fill="#333", width=1)
    # ears
    for (x,y) in [(98,68),(182,68)]:
        d.ellipse([x-10,y-10,x+10,y+10], fill="#ffcc02", outline="#f9a825", width=2)
        d.ellipse([x-5,y-5,x+5,y+5], fill="#ff8a65")
    # paws
    for (x,y) in [(90,180),(175,180)]:
        d.ellipse([x-8,y-5,x+8,y+5], fill="#ffcc02", outline="#f9a825", width=1)
    save("homyak", img)

def cvetok():
    img, d = create_bg("#fff3e0")
    d.rectangle([137,120,143,230], fill="#4caf50")
    for (cx,cy,rot) in [(140,70,0),(140,70,60),(140,70,120),(140,70,180),(140,70,240),(140,70,300)]:
        rad = math.radians(rot)
        ex = cx + 20*math.sin(rad)
        ey = cy - 20*math.cos(rad)
        d.ellipse([ex-12,ey-20,ex+12,ey+20], fill="#e53935", outline="#333", width=2)
    # center
    d.ellipse([125,80,155,105], fill="#FFD700", outline="#f9a825", width=2)
    for (x,y) in [(132,86),(145,88),(138,95),(128,93),(150,93)]:
        d.ellipse([x-2,y-2,x+2,y+2], fill="#ff8f00")
    # leaves
    for (dx,dy) in [(1,1), (-1,-1)]:
        d.arc([120+dx*30,160+dy*10,150+dx*20,190+dy*20], 180+90*dy, 360+90*(-dy), fill="#66bb6a", width=10)
    save("cvetok", img)

def chayka():
    img, d = create_bg("#e3f2fd")
    d.ellipse([110,145,175,200], fill="#fff", outline="#9e9e9e", width=3)
    # wings
    d.polygon([120,160,90,125,175,115,150,150], fill="#e0e0e0", outline="#9e9e9e", width=2)
    d.polygon([175,115,205,80,215,95,190,130], fill="#f5f5f5", outline="#9e9e9e", width=2)
    d.ellipse([168,132,200,175], fill="#fff", outline="#9e9e9e", width=3)
    d.ellipse([188,140,198,152], fill="#333")
    d.polygon([198,150,228,145,200,155], fill="#ff8f00", outline="#e65100", width=1)
    d.polygon([115,175,90,160,95,185], fill="#fff", outline="#9e9e9e", width=2)
    d.line([140,195,140,225], fill="#ff8f00", width=3)
    d.line([160,195,160,225], fill="#ff8f00", width=3)
    save("chayka", img)

def shapka():
    img, d = create_bg("#ffebee")
    d.polygon([40,145,40,65,240,65,240,145], fill="#e53935", outline="#333", width=3)
    d.ellipse([40,140,240,165], fill="#e53935", outline="#333", width=3)
    d.rectangle([55,100,225,108], fill="#fff")
    d.rectangle([50,118,230,124], fill="#fff")
    d.ellipse([120,45,160,85], fill="#fff", outline="#e0e0e0", width=2)
    d.ellipse([130,52,150,75], fill="#f5f5f5")
    for (x,y) in [(75,95),(105,88),(140,85),(175,88),(205,95)]:
        d.ellipse([x-4,y-4,x+4,y+4], fill="#fff")
    save("shapka", img)

def shchenok():
    img, d = create_bg("#efebe9")
    d.ellipse([95,145,185,210], fill="#d7ccc8", outline="#8d6e63", width=3)
    d.ellipse([100,75,180,158], fill="#d7ccc8", outline="#8d6e63", width=3)
    # floppy ears
    for (x,y) in [(92,120),(188,120)]:
        d.ellipse([x-15,y-20,x+15,y+25], fill="#a1887f", outline="#8d6e63", width=2)
    d.ellipse([115,100,127,115], fill="#333")
    d.ellipse([153,100,165,115], fill="#333")
    d.ellipse([117,103,125,113], fill="#fff")
    d.ellipse([155,103,163,113], fill="#fff")
    d.ellipse([133,118,147,128], fill="#333")
    d.arc([130,132,150,140], 0, 180, fill="#333", width=1)
    d.ellipse([135,136,145,142], fill="#e53935")
    d.ellipse([115,90,132,106], fill="#8d6e63")
    d.line([105,170,75,148], fill="#d7ccc8", width=6)
    for (x,y) in [(100,200),(172,200)]:
        d.ellipse([x-10,y-6,x+10,y+6], fill="#d7ccc8", outline="#8d6e63", width=1)
    save("shchenok", img)

def ekskavator():
    img, d = create_bg("#fffde7")
    d.rectangle([85,115,195,180], fill="#ffcc02", outline="#f9a825", width=3)
    d.rectangle([92,125,135,158], fill="#bbdefb", outline="#1565c0", width=2)
    d.rectangle([90,108,190,118], fill="#ff8f00", outline="#e65100", width=2)
    d.rectangle([195,130,250,142], fill="#ffcc02", outline="#f9a825", width=2)
    d.polygon([245,130,260,130,260,175,225,175,225,150], fill="#e53935", outline="#333", width=2)
    d.line([230,175,230,182], fill="#333", width=2)
    d.line([240,175,240,182], fill="#333", width=2)
    d.line([250,175,250,182], fill="#333", width=2)
    d.rectangle([75,175,205,198], fill="#555", outline="#333", width=2)
    for x in [95,125,155,185]:
        d.ellipse([x-7,182,x+7,196], fill="#777", outline="#333", width=1)
    d.rectangle([102,92,112,115], fill="#777", outline="#555", width=2)
    d.ellipse([195,148,205,158], fill="#FFD700", outline="#f9a825", width=1)
    save("ekskavator", img)

def yula():
    img, d = create_bg("#e3f2fd")
    d.polygon([140,45,175,95,175,135,155,155,125,155,105,135,105,95], fill="#2196f3", outline="#1565c0", width=3)
    d.rectangle([112,78,168,90], fill="#e53935")
    d.rectangle([105,100,175,112], fill="#FFD700")
    d.polygon([125,155,155,155,140,200], fill="#9e9e9e", outline="#616161", width=2)
    d.rectangle([133,18,147,45], fill="#9e9e9e", outline="#616161", width=2)
    d.ellipse([130,10,150,28], fill="#e53935", outline="#333", width=2)
    for (dx,dy) in [(-70,-11),(-80,-22),(-62,6),(-73,-5)]:
        d.line([140+dx,150+dy,140+dx-10,150+dy-10], fill="#90caf9", width=2)
    for (dx,dy) in [(70,11),(80,22),(62,-6),(73,5)]:
        d.line([140+dx,150+dy,140+dx+10,150+dy+10], fill="#90caf9", width=2)
    save("yula", img)

def yabloko():
    img, d = create_bg("#ffebee")
    d.ellipse([90,85,190,195], fill="#e53935", outline="#333", width=3)
    d.ellipse([100,105,125,148], fill="#ef5350")
    d.line([140,85,140,65], fill="#795548", width=4)
    d.arc([125,75,168,92], -30, 90, fill="#4caf50", width=6)
    save("yabloko", img)

def volk():
    img, d = create_bg("#f5f5f5")
    d.ellipse([90,130,195,200], fill="#9e9e9e", outline="#555", width=3)
    d.ellipse([70,90,155,150], fill="#9e9e9e", outline="#555", width=3)
    d.ellipse([82,108,98,125], fill="#333")
    d.ellipse([112,108,128,125], fill="#333")
    d.polygon([80,125,70,140,95,130], fill="#e0e0e0")
    d.ellipse([130,85,160,120], fill="#9e9e9e", outline="#555", width=2)
    d.ellipse([138,95,152,112], fill="#e0e0e0")
    # ears
    d.polygon([70,90,60,60,85,80], fill="#9e9e9e", outline="#555", width=2)
    d.polygon([145,85,155,55,165,80], fill="#9e9e9e", outline="#555", width=2)
    d.polygon([73,85,65,65,83,78], fill="#e0e0e0")
    d.polygon([147,80,154,60,161,78], fill="#e0e0e0")
    # tail
    d.ellipse([185,165,235,200], fill="#9e9e9e", outline="#555", width=3)
    for x in [100,170]:
        d.rectangle([x,195,x+14,245], fill="#9e9e9e", outline="#555", width=2)
    save("volk", img)

def grib():
    img, d = create_bg("#fff8e1")
    d.rectangle([125,155,145,235], fill="#f5f5f5", outline="#9e9e9e", width=3)
    d.ellipse([60,80,210,170], fill="#e53935", outline="#333", width=3)
    d.ellipse([65,110,205,165], fill="#f44336")
    # spots
    for (x,y,r) in [(90,110,10),(130,100,14),(170,115,10),(110,140,8),(160,140,12)]:
        d.ellipse([x-r,y-r,x+r,y+r], fill="#fff")
    d.ellipse([130,145,145,158], fill="#f5f5f5")
    save("grib", img)

def yozh():
    img, d = create_bg("#e8f5e9")
    d.ellipse([80,120,190,195], fill="#8d6e63", outline="#5d4037", width=3)
    # spines
    for i in range(12):
        a = math.radians(i*30 - 60)
        x = 140 + 55*math.cos(a)
        y = 150 + 45*math.sin(a)
        ex = x + 18*math.cos(a)
        ey = y + 15*math.sin(a)
        d.line([x,y,ex,ey], fill="#555", width=2)
    d.ellipse([120,140,160,190], fill="#d7ccc8", outline="#8d6e63", width=2)
    d.ellipse([133,148,142,158], fill="#333")
    d.ellipse([148,148,157,158], fill="#333")
    d.ellipse([137,160,153,167], fill="#333")
    d.ellipse([90,135,120,160], fill="#8d6e63", outline="#5d4037", width=2)
    save("yozh", img)

def zhuk():
    img, d = create_bg("#fffde7")
    d.ellipse([90,120,190,200], fill="#5d4037", outline="#333", width=3)
    # wing line
    d.line([140,120,140,200], fill="#333", width=2)
    d.ellipse([80,115,200,145], fill="#333", outline="#111", width=3)
    # eyes
    d.ellipse([110,120,125,135], fill="#fff")
    d.ellipse([155,120,170,135], fill="#fff")
    d.ellipse([113,124,122,133], fill="#333")
    d.ellipse([158,124,167,133], fill="#333")
    # antennae
    d.line([108,118,85,90], fill="#333", width=2)
    d.line([172,118,195,90], fill="#333", width=2)
    d.ellipse([80,85,90,95], fill="#333")
    d.ellipse([190,85,200,95], fill="#333")
    # legs
    for (dx,dy) in [(-30,20),(30,20),(-25,35),(25,35),(-20,50),(20,50)]:
        d.line([140,150,140+dx,150+dy], fill="#333", width=2)
    # dots
    d.ellipse([110,155,122,167], fill="#FFD700")
    d.ellipse([158,155,170,167], fill="#FFD700")
    d.ellipse([115,175,125,185], fill="#FFD700")
    d.ellipse([155,175,165,185], fill="#FFD700")
    save("zhuk", img)

def iriska():
    img, d = create_bg("#fce4ec")
    d.polygon([80,100,200,100,180,220,100,220], fill="#ff8a65", outline="#e65100", width=3)
    d.polygon([85,105,195,105,178,215,102,215], fill="#ffab91")
    # wrapper
    d.line([80,100,140,70,200,100], fill="#e53935", width=6)
    d.line([80,100,140,70,200,100], fill="#333", width=8)
    d.line([80,100,140,70,200,100], fill="#e53935", width=5)
    d.line([100,220,140,250,180,220], fill="#e53935", width=5)
    d.line([100,220,140,250,180,220], fill="#333", width=8)
    d.line([100,220,140,250,180,220], fill="#e53935", width=5)
    # label
    d.ellipse([130,135,150,165], fill="#FFD700")
    d.ellipse([133,140,147,158], fill="#fff")
    save("iriska", img)

def kot():
    img, d = create_bg("#fff3e0")
    d.ellipse([95,130,185,200], fill="#ff8f00", outline="#e65100", width=3)
    d.ellipse([80,80,160,148], fill="#ff8f00", outline="#e65100", width=3)
    # ears
    d.polygon([80,90,70,55,98,78], fill="#ff8f00", outline="#e65100", width=2)
    d.polygon([160,88,175,55,185,78], fill="#ff8f00", outline="#e65100", width=2)
    d.polygon([82,85,75,62,95,78], fill="#ffcc80")
    d.polygon([162,84,173,62,182,78], fill="#ffcc80")
    # eyes
    d.ellipse([100,100,115,115], fill="#4caf50")
    d.ellipse([125,100,140,115], fill="#4caf50")
    d.ellipse([103,103,112,112], fill="#333")
    d.ellipse([128,103,137,112], fill="#333")
    d.ellipse([105,105,110,110], fill="#fff")
    d.ellipse([131,105,136,110], fill="#fff")
    d.polygon([110,122,120,112,130,122], fill="#e91e63")
    # whiskers
    d.line([85,120,55,115], fill="#555", width=1)
    d.line([85,125,55,125], fill="#555", width=1)
    d.line([85,130,55,135], fill="#555", width=1)
    d.line([155,120,185,115], fill="#555", width=1)
    d.line([155,125,185,125], fill="#555", width=1)
    d.line([155,130,185,135], fill="#555", width=1)
    # tail
    d.ellipse([175,170,225,205], fill="#ff8f00", outline="#e65100", width=3)
    # stripes
    d.line([100,90,108,80], fill="#e65100", width=2)
    d.line([120,85,120,75], fill="#e65100", width=2)
    d.line([145,88,138,78], fill="#e65100", width=2)
    for x in [105,155]:
        d.rectangle([x,195,x+12,245], fill="#ff8f00", outline="#e65100", width=2)
    save("kot", img)

def medved():
    img, d = create_bg("#efebe9")
    d.ellipse([85,130,195,205], fill="#8d6e63", outline="#5d4037", width=3)
    d.ellipse([65,75,155,155], fill="#8d6e63", outline="#5d4037", width=3)
    # ears
    d.ellipse([55,65,85,95], fill="#8d6e63", outline="#5d4037", width=2)
    d.ellipse([60,70,80,90], fill="#a1887f")
    d.ellipse([135,65,165,95], fill="#8d6e63", outline="#5d4037", width=2)
    d.ellipse([140,70,160,90], fill="#a1887f")
    d.ellipse([92,100,108,116], fill="#333")
    d.ellipse([118,100,134,116], fill="#333")
    d.ellipse([95,110,131,124], fill="#333")
    d.ellipse([95,124,131,134], fill="#795548")
    # belly
    d.ellipse([100,155,170,195], fill="#a1887f")
    for x in [95,165]:
        d.rectangle([x,200,x+18,245], fill="#8d6e63", outline="#5d4037", width=2)
    save("medved", img)

def okno():
    img, d = create_bg("#e3f2fd")
    d.rounded_rectangle([40,40,240,235], 10, fill="#ffcc80", outline="#e65100", width=4)
    d.rounded_rectangle([50,50,230,225], 8, fill="#bbdefb", outline="#1565c0", width=3)
    d.line([140,50,140,225], fill="#1565c0", width=3)
    d.line([50,138,230,138], fill="#1565c0", width=3)
    # curtains
    d.polygon([50,50,50,225,85,165,85,50], fill="#e91e63")
    d.polygon([230,50,230,225,195,165,195,50], fill="#e91e63")
    # flower on sill
    d.ellipse([130,195,150,215], fill="#4caf50")
    d.ellipse([125,185,155,210], fill="#f44336")
    d.ellipse([132,192,148,205], fill="#FFD700")
    save("okno", img)

def ryba():
    img, d = create_bg("#e1f5fe")
    d.ellipse([70,120,200,180], fill="#4fc3f7", outline="#0288d1", width=3)
    d.polygon([75,125,25,95,25,185], fill="#4fc3f7", outline="#0288d1", width=3)
    d.polygon([90,108,115,70,145,105], fill="#81d4fa", outline="#0288d1", width=2)
    d.ellipse([180,135,192,150], fill="#fff")
    d.ellipse([183,138,189,147], fill="#333")
    d.arc([195,148,210,160], -20, 20, fill="#0288d1", width=2)
    for (x,y) in [(120,130),(140,128),(160,132),(130,142),(150,145),(155,155)]:
        d.ellipse([x-3,y-3,x+3,y+3], fill="#0288d1")
    d.line([130,120,130,172], fill="#0277bd", width=2)
    d.line([150,122,150,170], fill="#0277bd", width=2)
    save("ryba", img)

def sova():
    img, d = create_bg("#fff3e0")
    d.ellipse([90,100,190,205], fill="#8d6e63", outline="#5d4037", width=3)
    d.ellipse([80,55,200,140], fill="#8d6e63", outline="#5d4037", width=3)
    # facial disc
    d.ellipse([90,70,150,130], fill="#d7ccc8")
    d.ellipse([130,70,190,130], fill="#d7ccc8")
    # eyes
    d.ellipse([100,80,135,115], fill="#fff")
    d.ellipse([140,80,180,115], fill="#fff")
    d.ellipse([108,88,128,108], fill="#ff8f00")
    d.ellipse([148,88,172,108], fill="#ff8f00")
    d.ellipse([112,93,124,105], fill="#333")
    d.ellipse([152,93,168,105], fill="#333")
    # beak
    d.polygon([120,118,140,108,160,118], fill="#FFD700", outline="#f9a825", width=1)
    # ear tufts
    d.polygon([80,60,70,30,95,55], fill="#8d6e63", outline="#5d4037", width=2)
    d.polygon([200,60,210,30,185,55], fill="#8d6e63", outline="#5d4037", width=2)
    # wings
    d.ellipse([60,130,90,190], fill="#8d6e63", outline="#5d4037", width=2)
    d.ellipse([190,130,220,190], fill="#8d6e63", outline="#5d4037", width=2)
    # feet
    d.line([120,205,120,240], fill="#FFD700", width=3)
    d.line([115,240,125,240], fill="#FFD700", width=2)
    d.line([160,205,160,240], fill="#FFD700", width=3)
    d.line([155,240,165,240], fill="#FFD700", width=2)
    # chest feathers
    for (x,y) in [(115,145),(135,155),(155,145),(145,170),(125,170)]:
        d.ellipse([x-6,y-6,x+6,y+6], fill="#d7ccc8")
    save("sova", img)

def utka():
    img, d = create_bg("#e3f2fd")
    d.ellipse([100,130,180,195], fill="#FFD700", outline="#f9a825", width=3)
    d.ellipse([85,88,155,148], fill="#FFD700", outline="#f9a825", width=3)
    d.ellipse([95,100,112,115], fill="#333")
    d.ellipse([128,100,145,115], fill="#333")
    d.polygon([68,130,48,140,68,142], fill="#ff8f00", outline="#e65100", width=1)
    # wing
    d.ellipse([100,145,140,180], fill="#ffcc02", outline="#f9a825", width=2)
    # tail
    d.polygon([175,155,210,145,200,170], fill="#ffcc02")
    # neck ring
    d.ellipse([108,138,150,160], fill="#fff")
    d.line([115,195,115,230], fill="#ff8f00", width=3)
    d.line([150,195,150,230], fill="#ff8f00", width=3)
    save("utka", img)

def filin():
    img, d = create_bg("#f5f5f5")
    d.ellipse([90,120,190,210], fill="#795548", outline="#4e342e", width=3)
    d.ellipse([65,70,215,150], fill="#795548", outline="#4e342e", width=3)
    # facial disc
    d.ellipse([80,80,145,135], fill="#d7ccc8")
    d.ellipse([135,80,200,135], fill="#d7ccc8")
    # eyes
    d.ellipse([95,90,130,120], fill="#fff")
    d.ellipse([150,90,185,120], fill="#fff")
    d.ellipse([105,98,120,113], fill="#ff8f00")
    d.ellipse([160,98,175,113], fill="#ff8f00")
    d.ellipse([108,102,117,111], fill="#333")
    d.ellipse([163,102,172,111], fill="#333")
    d.polygon([130,125,140,115,150,125], fill="#FFD700", outline="#f9a825", width=1)
    # horns (ear tufts)
    d.polygon([70,75,60,40,95,70], fill="#795548", outline="#4e342e", width=2)
    d.polygon([210,75,220,40,185,70], fill="#795548", outline="#4e342e", width=2)
    # wings
    d.ellipse([55,140,90,200], fill="#795548", outline="#4e342e", width=2)
    d.ellipse([190,140,225,200], fill="#795548", outline="#4e342e", width=2)
    d.line([130,210,130,240], fill="#FFD700", width=3)
    d.line([150,210,150,240], fill="#FFD700", width=3)
    save("filin", img)

def hleb():
    img, d = create_bg("#fff8e1")
    d.ellipse([60,90,220,190], fill="#ffcc02", outline="#f9a825", width=3)
    d.ellipse([70,100,210,180], fill="#ffe082", outline="#f9a825", width=2)
    # bread scoring
    d.line([90,130,110,125], fill="#b8860b", width=2)
    d.line([110,125,130,128], fill="#b8860b", width=2)
    d.line([130,128,150,122], fill="#b8860b", width=2)
    d.line([150,122,170,128], fill="#b8860b", width=2)
    d.line([170,128,190,125], fill="#b8860b", width=2)
    # highlight
    d.ellipse([85,110,195,130], fill="#fff9c4")
    save("hleb", img)

def shenok():
    img, d = create_bg("#efebe9")
    d.ellipse([95,145,185,210], fill="#d7ccc8", outline="#8d6e63", width=3)
    d.ellipse([100,75,180,158], fill="#d7ccc8", outline="#8d6e63", width=3)
    for (x,y) in [(92,120),(188,120)]:
        d.ellipse([x-15,y-20,x+15,y+25], fill="#a1887f", outline="#8d6e63", width=2)
    d.ellipse([115,100,127,115], fill="#333")
    d.ellipse([153,100,165,115], fill="#333")
    d.ellipse([117,103,125,113], fill="#fff")
    d.ellipse([155,103,163,113], fill="#fff")
    d.ellipse([133,118,147,128], fill="#333")
    d.arc([130,132,150,140], 0, 180, fill="#333", width=1)
    d.ellipse([135,136,145,142], fill="#e53935")
    d.ellipse([115,90,132,106], fill="#8d6e63")
    d.line([105,170,75,148], fill="#d7ccc8", width=6)
    for (x,y) in [(100,200),(172,200)]:
        d.ellipse([x-10,y-6,x+10,y+6], fill="#d7ccc8", outline="#8d6e63", width=1)
    save("shenok", img)

def podjezd():
    img, d = create_bg("#e3f2fd")
    # building wall
    d.rectangle([30,50,250,250], fill="#e0e0e0", outline="#9e9e9e", width=3)
    # roof
    d.rectangle([25,40,255,55], fill="#795548", outline="#4e342e", width=2)
    # door (entrance)
    d.rectangle([95,120,185,250], fill="#455a64", outline="#263238", width=3)
    d.rectangle([100,130,180,245], fill="#546e7a")
    d.ellipse([170,185,180,195], fill="#FFD700")
    # windows
    for (x,y) in [(45,70),(210,70),(45,180),(210,180)]:
        d.rectangle([x,y,x+40,y+55], fill="#bbdefb", outline="#1565c0", width=2)
        d.line([x+20,y,x+20,y+55], fill="#1565c0", width=1)
        d.line([x,y+27,x+40,y+27], fill="#1565c0", width=1)
    # steps
    for i in range(3):
        d.rectangle([88+i*3,250-i*8,192-i*3,250-i*8+8], fill="#e0e0e0", outline="#9e9e9e", width=1)
    # door number
    save("podjezd", img)

def syr():
    img, d = create_bg("#fffde7")
    d.polygon([60,80,140,40,220,80,200,200,100,200], fill="#FFD700", outline="#f9a825", width=3)
    # holes
    for (x,y,r) in [(120,100,12),(160,95,8),(105,140,10),(175,130,9),(140,160,6),(90,170,7)]:
        d.ellipse([x-r,y-r,x+r,y+r], fill="#e6c80a")
    save("syr", img)

def los():
    img, d = create_bg("#f5f5f5")
    d.ellipse([95,140,195,205], fill="#a1887f", outline="#5d4037", width=3)
    d.ellipse([65,90,145,158], fill="#a1887f", outline="#5d4037", width=3)
    # antlers
    for (dx,flip) in [(0,1),(60,-1)]:
        basex = 80+dx
        d.line([basex,85,basex-20,40], fill="#8d6e63", width=4)
        d.line([basex-20,40,basex-35,30], fill="#8d6e63", width=3)
        d.line([basex-20,40,basex-10,25], fill="#8d6e63", width=3)
        d.line([basex-20,50,basex-5,40], fill="#8d6e63", width=2)
    # ears
    d.ellipse([55,82,70,105], fill="#a1887f", outline="#5d4037", width=1)
    d.ellipse([145,82,160,105], fill="#a1887f", outline="#5d4037", width=1)
    d.ellipse([85,105,100,118], fill="#333")
    d.ellipse([115,105,130,118], fill="#333")
    d.ellipse([95,118,120,128], fill="#333")
    # bell (muzzle)
    d.ellipse([100,125,115,138], fill="#e0e0e0")
    for x in [105,165]:
        d.rectangle([x,200,x+16,245], fill="#a1887f", outline="#5d4037", width=2)
    save("los", img)

def eskimo():
    img, d = create_bg("#fce4ec")
    d.rectangle([70,60,210,220], fill="#fff9c4", outline="#f9a825", width=3)
    d.rectangle([75,65,205,215], fill="#fff")
    # stick
    d.rectangle([128,200,152,245], fill="#8d6e63")
    # ice cream top
    d.ellipse([90,60,190,120], fill="#e53935")
    d.ellipse([100,65,180,110], fill="#ef5350")
    # chocolate coating
    d.rectangle([75,115,205,155], fill="#795548")
    d.rectangle([80,120,200,150], fill="#5d4037")
    # label
    d.rounded_rectangle([95,130,185,195], 5, fill="#FFD700")
    d.text((130,148), "ЭСКИМО", fill="#e53935", font_size=11)
    # drip
    d.ellipse([160,150,170,165], fill="#795548")
    save("eskimo", img)

# ─── MAIN ────────────────────────────────────────────────────────────────────

def main():
    os.makedirs(OUT, exist_ok=True)
    gen = [arbuz, banan, cherepaha, cyplenok, dom, enot, yolka, zhiraf, zebra,
           igla, yogurt, kit, lisa, malina, nosorog, okun, pingvin, raduga,
           slon, tigr, ulitka, flamingo, homyak, cvetok, chayka, shapka,
           shchenok, ekskavator, yula, yabloko,
           volk, grib, yozh, zhuk, iriska, kot, medved, okno, ryba, sova,
           utka, filin, hleb, shenok, podjezd, syr, los, eskimo]
    print(f"Generating {len(gen)} illustrations...")
    for f in gen:
        f()
    print(f"Done! {len(gen)} images in {OUT}")

if __name__ == "__main__":
    main()
