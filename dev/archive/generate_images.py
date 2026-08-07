#!/usr/bin/env python3
"""Generate colorful kid-friendly illustrations for Азбука game."""
import math, os
from PIL import Image, ImageDraw, ImageFont

OUT_DIR = "/Users/halapinvv/azbuka-pwa/assets/images"
os.makedirs(OUT_DIR, exist_ok=True)
SIZE = 280

def _load_font(size=20):
    paths = [
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Arial.ttf",
    ]
    for p in paths:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()

FONT = _load_font(18)

def new_canvas(r, g, b):
    img = Image.new("RGBA", (SIZE, SIZE), (r, g, b, 255))
    return img, ImageDraw.Draw(img)

def circle(draw, cx, cy, r, fill):
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=fill)

def rect(draw, x1, y1, x2, y2, fill, radius=0):
    if radius > 0:
        draw.rounded_rectangle([x1, y1, x2, y2], radius=radius, fill=fill)
    else:
        draw.rectangle([x1, y1, x2, y2], fill=fill)

def triangle(draw, points, fill):
    draw.polygon(points, fill=fill)

# ============== 33 illustrations ==============

def arbuz():
    img, d = new_canvas(200, 230, 200)
    # outer rind
    circle(d, 140, 170, 100, (80, 160, 60))
    # inner flesh
    circle(d, 140, 165, 85, (230, 80, 80))
    # seeds
    for sx, sy in [(120,150),(145,145),(160,160),(125,175),(155,180),(135,165),(150,150),(115,165)]:
        circle(d, sx, sy, 4, (30, 30, 30))
    # smile
    d.arc([110, 155, 170, 195], 0, 180, fill=(50,50,50), width=2)
    # eyes
    circle(d, 115, 140, 6, (30, 30, 30))
    circle(d, 165, 140, 6, (30, 30, 30))
    d.text((SIZE//2-30, 230), "Арбуз", fill=(50,50,50), font=FONT)
    return img

def banan():
    img, d = new_canvas(240, 230, 180)
    # banana body
    for i in range(3):
        d.ellipse([60+i*3, 80-i*5, 200+i*3, 220-i*5], fill=(230, 210, 50))
    # stem
    rect(d, 55, 75, 75, 105, fill=(100, 160, 40))
    d.text((SIZE//2-25, 240), "Банан", fill=(50,50,50), font=FONT)
    return img

def volk():
    img, d = new_canvas(180, 200, 220)
    # body
    circle(d, 140, 180, 60, (160, 160, 170))
    # head
    circle(d, 140, 130, 45, (160, 160, 170))
    # ears
    triangle(d, [(110,100), (120,65), (135,95)], fill=(160,160,170))
    triangle(d, [(145,95), (160,65), (170,100)], fill=(160,160,170))
    # inner ears
    triangle(d, [(115,98), (122,72), (132,95)], fill=(230, 180, 180))
    triangle(d, [(148,95), (158,72), (165,98)], fill=(230, 180, 180))
    # eyes
    circle(d, 120, 120, 6, (50, 50, 180))
    circle(d, 158, 120, 6, (50, 50, 180))
    # nose
    circle(d, 140, 140, 5, (30, 30, 30))
    d.text((SIZE//2-20, 240), "Волк", fill=(50,50,50), font=FONT)
    return img

def grib():
    img, d = new_canvas(200, 220, 190)
    # stem
    rect(d, 110, 140, 170, 280, fill=(240, 230, 210), radius=8)
    # cap
    d.arc([55, 80, 225, 180], 180, 360, fill=(180, 80, 60), width=50)
    circle(d, 140, 100, 80, (180, 80, 60))
    # dots
    for sx, sy in [(100,90),(160,85),(120,75),(180,95),(80,105),(150,100)]:
        circle(d, sx, sy, 8, (240, 230, 220))
    # face
    circle(d, 120, 120, 4, (30,30,30))
    circle(d, 158, 120, 4, (30,30,30))
    d.arc([115, 125, 165, 155], 0, 180, fill=(30,30,30), width=2)
    d.text((SIZE//2-18, 245), "Гриб", fill=(50,50,50), font=FONT)
    return img

def dom():
    img, d = new_canvas(200, 220, 240)
    # walls
    rect(d, 60, 120, 220, 270, fill=(240, 220, 180), radius=4)
    # roof
    triangle(d, [(30, 120), (140, 40), (250, 120)], fill=(180, 80, 60))
    # door
    rect(d, 120, 170, 170, 270, fill=(150, 100, 70), radius=6)
    # window
    rect(d, 75, 140, 115, 180, fill=(180, 220, 255), radius=4)
    rect(d, 165, 140, 205, 180, fill=(180, 220, 255), radius=4)
    d.text((SIZE//2-18, 250), "Дом", fill=(50,50,50), font=FONT)
    return img

def enot():
    img, d = new_canvas(190, 210, 190)
    # tail
    d.ellipse([170, 100, 250, 190], fill=(180, 180, 170))
    for i in range(4):
        d.ellipse([170+i*18, 95+i*5, 200+i*18, 130+i*5], fill=(60, 60, 60))
    # body
    circle(d, 130, 180, 55, (170, 170, 160))
    # head
    circle(d, 110, 110, 40, (170, 170, 160))
    # mask
    d.ellipse([85, 100, 135, 120], fill=(40, 40, 40))
    # eyes
    circle(d, 100, 108, 5, (255, 255, 255))
    circle(d, 120, 108, 5, (255, 255, 255))
    circle(d, 100, 108, 2, (0, 0, 0))
    circle(d, 120, 108, 2, (0, 0, 0))
    d.text((SIZE//2-20, 250), "Енот", fill=(50,50,50), font=FONT)
    return img

def yozh():
    img, d = new_canvas(200, 210, 180)
    # body (spines)
    for i in range(20):
        x = 80 + (i % 10) * 14
        y = 80 + (i // 10) * 14
        triangle(d, [(x, y-10), (x-6, y+2), (x+6, y+2)], fill=(120, 80, 50))
    # body oval
    d.ellipse([80, 120, 200, 200], fill=(180, 150, 120))
    # face
    circle(d, 100, 150, 8, (30, 30, 30))
    d.text((SIZE//2-16, 240), "Ёж", fill=(50,50,50), font=FONT)
    return img

def zhuk():
    img, d = new_canvas(200, 210, 180)
    # body
    d.ellipse([80, 120, 200, 230], fill=(60, 60, 160))
    # wings
    d.arc([85, 125, 195, 225], 0, 360, fill=(80, 80, 190), width=4)
    # head
    circle(d, 100, 110, 20, (40, 40, 40))
    # eyes
    circle(d, 90, 105, 5, (255, 255, 100))
    circle(d, 108, 105, 5, (255, 255, 100))
    # dots
    circle(d, 130, 150, 6, (200, 200, 100))
    circle(d, 160, 160, 6, (200, 200, 100))
    d.text((SIZE//2-18, 250), "Жук", fill=(50,50,50), font=FONT)
    return img

def zebra():
    img, d = new_canvas(200, 220, 230)
    # body
    d.ellipse([60, 160, 180, 250], fill=(240, 240, 240))
    # stripes
    for i in range(5):
        x = 70 + i * 22
        d.polygon([(x, 160), (x+8, 160), (x+4, 250), (x-4, 250)], fill=(30, 30, 30))
    # neck
    d.ellipse([60, 80, 120, 180], fill=(240, 240, 240))
    for i in range(3):
        x = 65 + i * 16
        d.polygon([(x, 80), (x+8, 80), (x+4, 180), (x-4, 180)], fill=(30, 30, 30))
    # head
    d.ellipse([50, 40, 110, 95], fill=(240, 240, 240))
    # muzzle
    d.ellipse([90, 55, 115, 85], fill=(200, 180, 200))
    d.text((SIZE//2-25, 260), "Зебра", fill=(50,50,50), font=FONT)
    return img

def iris():
    img, d = new_canvas(245, 200, 200)
    # wrapper
    d.rectangle([60, 100, 220, 200], fill=(255, 200, 150), outline=(200, 150, 100))
    d.rectangle([60, 100, 220, 115], fill=(200, 150, 100))
    # candy
    circle(d, 140, 155, 35, (255, 200, 50))
    circle(d, 140, 155, 25, (200, 150, 50))
    d.text((SIZE//2-28, 230), "Ириска", fill=(50,50,50), font=FONT)
    return img

def yogurt():
    img, d = new_canvas(230, 230, 255)
    # cup
    d.ellipse([70, 100, 210, 180], fill=(255, 255, 255), outline=(180, 180, 180))
    rect(d, 80, 130, 200, 210, fill=(240, 240, 255), radius=6)
    # label
    d.rounded_rectangle([85, 140, 195, 180], radius=4, fill=(255, 200, 200))
    # spoon
    d.ellipse([195, 60, 215, 100], fill=(200, 200, 200))
    d.text((SIZE//2-30, 240), "Йогурт", fill=(50,50,50), font=FONT)
    return img

def kot():
    img, d = new_canvas(230, 220, 240)
    # body
    circle(d, 140, 180, 55, (255, 200, 150))
    # head
    circle(d, 140, 110, 40, (255, 200, 150))
    # ears
    triangle(d, [(105,85), (115,45), (130,80)], fill=(255, 200, 150))
    triangle(d, [(150,80), (165,45), (175,85)], fill=(255, 200, 150))
    # inner ears
    triangle(d, [(110,83), (117,55), (127,80)], fill=(255, 150, 150))
    triangle(d, [(153,80), (163,55), (170,83)], fill=(255, 150, 150))
    # eyes
    circle(d, 120, 105, 7, (50, 180, 50))
    circle(d, 158, 105, 7, (50, 180, 50))
    circle(d, 120, 105, 3, (0, 0, 0))
    circle(d, 158, 105, 3, (0, 0, 0))
    # nose
    triangle(d, [(137, 118), (143, 118), (140, 123)], fill=(255, 100, 100))
    # whiskers
    for wx, wy in [(105,115),(115,118),(105,125),(175,115),(165,118),(175,125)]:
        d.line([(140 if wx>140 else 80, wy), (wx, wy)], fill=(100,100,100), width=1)
    d.text((SIZE//2-16, 250), "Кот", fill=(50,50,50), font=FONT)
    return img

def lisa():
    img, d = new_canvas(220, 200, 180)
    # bushy tail
    d.ellipse([170, 130, 250, 210], fill=(230, 150, 60))
    d.ellipse([225, 115, 255, 145], fill=(255, 255, 255))
    # body
    d.ellipse([115, 140, 200, 220], fill=(230, 150, 60))
    # head
    circle(d, 110, 110, 35, (230, 150, 60))
    # ears
    triangle(d, [(80,90), (95,50), (105,85)], fill=(230, 150, 60))
    triangle(d, [(115,85), (130,50), (140,90)], fill=(230, 150, 60))
    # white muzzle
    d.ellipse([90, 105, 130, 135], fill=(255, 220, 200))
    # eyes
    circle(d, 95, 105, 4, (30, 30, 30))
    circle(d, 125, 105, 4, (30, 30, 30))
    d.text((SIZE//2-20, 250), "Лиса", fill=(50,50,50), font=FONT)
    return img

def medved():
    img, d = new_canvas(180, 160, 140)
    # body
    circle(d, 140, 180, 65, (140, 100, 70))
    # belly
    circle(d, 140, 190, 40, (180, 150, 120))
    # head
    circle(d, 140, 95, 45, (140, 100, 70))
    # ears
    circle(d, 100, 60, 18, (140, 100, 70))
    circle(d, 180, 60, 18, (140, 100, 70))
    circle(d, 100, 60, 10, (180, 150, 120))
    circle(d, 180, 60, 10, (180, 150, 120))
    # eyes
    circle(d, 125, 85, 5, (30, 30, 30))
    circle(d, 155, 85, 5, (30, 30, 30))
    # nose
    circle(d, 140, 100, 6, (30, 30, 30))
    d.text((SIZE//2-35, 255), "Медведь", fill=(50,50,50), font=FONT)
    return img

def nosorog():
    img, d = new_canvas(180, 190, 170)
    # body
    d.ellipse([70, 150, 220, 240], fill=(170, 170, 160))
    # head
    d.ellipse([40, 100, 120, 170], fill=(170, 170, 160))
    # horn
    triangle(d, [(60, 105), (80, 105), (70, 70)], fill=(200, 200, 180))
    # eye
    circle(d, 65, 120, 4, (30, 30, 30))
    d.text((SIZE//2-35, 255), "Носорог", fill=(50,50,50), font=FONT)
    return img

def okno():
    img, d = new_canvas(200, 230, 250)
    # frame
    rect(d, 40, 50, 240, 250, fill=(180, 150, 100), radius=6)
    # glass
    rect(d, 55, 65, 110, 165, fill=(180, 220, 255), radius=2)
    rect(d, 130, 65, 225, 165, fill=(180, 220, 255), radius=2)
    rect(d, 55, 180, 225, 235, fill=(180, 220, 255), radius=2)
    # cross
    rect(d, 108, 65, 130, 235, fill=(180, 150, 100))
    rect(d, 55, 170, 225, 185, fill=(180, 150, 100))
    # sky
    d.ellipse([75, 80, 100, 105], fill=(255, 255, 200))
    d.ellipse([145, 75, 170, 100], fill=(255, 255, 200))
    d.text((SIZE//2-20, 260), "Окно", fill=(50,50,50), font=FONT)
    return img

def pingvin():
    img, d = new_canvas(180, 190, 200)
    # body
    d.ellipse([100, 120, 200, 250], fill=(30, 30, 40))
    # belly
    d.ellipse([115, 140, 185, 240], fill=(240, 240, 240))
    # head
    circle(d, 150, 95, 35, (30, 30, 40))
    # white face
    d.ellipse([130, 80, 170, 110], fill=(240, 240, 240))
    # eyes
    circle(d, 138, 88, 5, (30, 30, 30))
    circle(d, 162, 88, 5, (30, 30, 30))
    # beak
    triangle(d, [(145, 100), (155, 100), (150, 115)], fill=(255, 200, 50))
    d.text((SIZE//2-35, 260), "Пингвин", fill=(50,50,50), font=FONT)
    return img

def ryba():
    img, d = new_canvas(180, 200, 220)
    # body
    d.ellipse([60, 100, 200, 190], fill=(100, 180, 220))
    # tail
    triangle(d, [(185, 100), (185, 190), (250, 145)], fill=(100, 180, 220))
    # eye
    circle(d, 95, 128, 8, (255, 255, 255))
    circle(d, 95, 128, 4, (30, 30, 30))
    # scales
    for i in range(4):
        for j in range(3):
            d.arc([110+i*20, 125+j*15, 130+i*20, 145+j*15], 180, 360, fill=(80, 160, 200), width=2)
    # mouth
    d.arc([60, 140, 85, 155], 180, 360, fill=(200, 80, 80), width=2)
    # bubbles
    circle(d, 50, 110, 6, (200, 230, 255))
    circle(d, 35, 95, 4, (200, 230, 255))
    d.text((SIZE//2-20, 250), "Рыба", fill=(50,50,50), font=FONT)
    return img

def sova():
    img, d = new_canvas(180, 160, 150)
    # body
    d.ellipse([90, 130, 200, 250], fill=(140, 110, 80))
    # belly
    d.ellipse([115, 150, 175, 240], fill=(200, 180, 160))
    # head
    circle(d, 145, 100, 55, (140, 110, 80))
    # face
    circle(d, 125, 95, 25, (200, 190, 180))
    circle(d, 165, 95, 25, (200, 190, 180))
    # eyes
    circle(d, 125, 95, 10, (255, 255, 200))
    circle(d, 165, 95, 10, (255, 255, 200))
    circle(d, 125, 95, 5, (30, 30, 30))
    circle(d, 165, 95, 5, (30, 30, 30))
    # beak
    triangle(d, [(140, 105), (150, 105), (145, 118)], fill=(255, 200, 50))
    # tufts
    triangle(d, [(100, 55), (115, 60), (108, 40)], fill=(140, 110, 80))
    triangle(d, [(190, 55), (175, 60), (182, 40)], fill=(140, 110, 80))
    d.text((SIZE//2-20, 260), "Сова", fill=(50,50,50), font=FONT)
    return img

def tigr():
    img, d = new_canvas(200, 170, 130)
    # body
    d.ellipse([80, 150, 220, 250], fill=(230, 160, 60))
    # stripes
    for i in range(3):
        d.arc([90+i*35, 155, 120+i*35, 175], 180, 360, fill=(30, 30, 30), width=3)
    # head
    d.ellipse([70, 80, 150, 155], fill=(230, 160, 60))
    # ears
    d.ellipse([72, 68, 95, 95], fill=(230, 160, 60))
    d.ellipse([125, 68, 148, 95], fill=(230, 160, 60))
    d.ellipse([75, 72, 92, 90], fill=(255, 200, 200))
    d.ellipse([128, 72, 145, 90], fill=(255, 200, 200))
    # eyes
    d.ellipse([95, 100, 108, 115], fill=(100, 200, 100))
    d.ellipse([120, 100, 133, 115], fill=(100, 200, 100))
    circle(d, 100, 108, 3, (30, 30, 30))
    circle(d, 126, 108, 3, (30, 30, 30))
    d.text((SIZE//2-20, 260), "Тигр", fill=(50,50,50), font=FONT)
    return img

def utka():
    img, d = new_canvas(220, 230, 210)
    # body
    d.ellipse([80, 120, 200, 220], fill=(240, 220, 50))
    # head
    circle(d, 100, 90, 30, (240, 220, 50))
    # bill
    d.ellipse([65, 85, 100, 100], fill=(255, 180, 50))
    # eye
    circle(d, 90, 82, 4, (30, 30, 30))
    # wing
    d.ellipse([130, 130, 180, 185], fill=(220, 200, 40))
    d.text((SIZE//2-20, 250), "Утка", fill=(50,50,50), font=FONT)
    return img

def filin():
    img, d = new_canvas(170, 160, 150)
    # body
    d.ellipse([90, 130, 200, 250], fill=(160, 130, 100))
    # head
    d.ellipse([95, 65, 195, 145], fill=(160, 130, 100))
    # facial disc
    d.ellipse([105, 75, 145, 125], fill=(200, 180, 160))
    d.ellipse([145, 75, 185, 125], fill=(200, 180, 160))
    # eyes
    circle(d, 125, 100, 12, (255, 200, 50))
    circle(d, 165, 100, 12, (255, 200, 50))
    circle(d, 125, 100, 5, (30, 30, 30))
    circle(d, 165, 100, 5, (30, 30, 30))
    # beak
    triangle(d, [(140, 108), (150, 108), (145, 120)], fill=(255, 200, 50))
    d.text((SIZE//2-25, 260), "Филин", fill=(50,50,50), font=FONT)
    return img

def hleb():
    img, d = new_canvas(220, 200, 170)
    # bread loaf
    d.ellipse([60, 100, 220, 210], fill=(220, 180, 120))
    # crust top
    d.arc([60, 90, 220, 140], 180, 360, fill=(180, 140, 80), width=20)
    # scoring marks
    d.line([(95, 105), (105, 95)], fill=(160, 120, 60), width=2)
    d.line([(130, 102), (140, 92)], fill=(160, 120, 60), width=2)
    d.line([(165, 105), (175, 95)], fill=(160, 120, 60), width=2)
    d.text((SIZE//2-20, 250), "Хлеб", fill=(50,50,50), font=FONT)
    return img

def cyplenok():
    img, d = new_canvas(230, 240, 200)
    # body
    circle(d, 140, 175, 55, (255, 220, 50))
    # head
    circle(d, 140, 100, 35, (255, 220, 50))
    # beak
    triangle(d, [(130, 95), (150, 95), (140, 108)], fill=(255, 150, 50))
    # eyes
    circle(d, 125, 90, 5, (30, 30, 30))
    circle(d, 155, 90, 5, (30, 30, 30))
    # wing
    d.ellipse([110, 140, 140, 180], fill=(240, 200, 40))
    # feet
    d.line([(115, 230), (115, 250)], fill=(255, 150, 50), width=3)
    d.line([(165, 230), (165, 250)], fill=(255, 150, 50), width=3)
    d.line([(100, 250), (130, 250)], fill=(255, 150, 50), width=2)
    d.line([(150, 250), (180, 250)], fill=(255, 150, 50), width=2)
    # crest
    circle(d, 135, 70, 8, (255, 100, 50))
    circle(d, 150, 68, 6, (255, 100, 50))
    d.text((SIZE//2-40, 260), "Цыпленок", fill=(50,50,50), font=FONT)
    return img

def cherepaha():
    img, d = new_canvas(180, 190, 160)
    # shell
    d.ellipse([60, 110, 200, 210], fill=(80, 160, 60))
    # shell pattern
    d.ellipse([90, 130, 170, 190], fill=(100, 180, 80))
    for i in range(6):
        cx = 110 + (i % 3) * 25
        cy = 140 + (i // 3) * 20
        d.ellipse([cx-8, cy-6, cx+8, cy+6], fill=(60, 140, 40))
    # head
    d.ellipse([35, 120, 75, 155], fill=(100, 180, 80))
    # legs
    d.ellipse([65, 195, 85, 230], fill=(100, 180, 80))
    d.ellipse([175, 195, 195, 230], fill=(100, 180, 80))
    # eyes
    circle(d, 50, 128, 4, (30, 30, 30))
    circle(d, 68, 128, 4, (30, 30, 30))
    d.text((SIZE//2-45, 255), "Черепаха", fill=(50,50,50), font=FONT)
    return img

def shapka():
    img, d = new_canvas(210, 200, 220)
    # hat body
    d.ellipse([50, 110, 230, 200], fill=(80, 120, 200))
    # brim
    d.ellipse([30, 170, 250, 210], fill=(80, 120, 200))
    # pompom
    circle(d, 140, 100, 18, (200, 80, 80))
    # stripes
    d.arc([55, 130, 225, 170], 180, 360, fill=(120, 160, 220), width=12)
    d.arc([55, 135, 225, 175], 180, 360, fill=(80, 120, 200), width=8)
    d.text((SIZE//2-30, 250), "Шапка", fill=(50,50,50), font=FONT)
    return img

def shenok():
    img, d = new_canvas(200, 190, 180)
    # body
    d.ellipse([100, 140, 200, 240], fill=(200, 180, 150))
    # head
    circle(d, 130, 100, 40, (200, 180, 150))
    # ears (floppy)
    d.ellipse([88, 75, 108, 115], fill=(180, 160, 130))
    d.ellipse([152, 75, 172, 115], fill=(180, 160, 130))
    # eyes
    circle(d, 115, 95, 6, (30, 30, 30))
    circle(d, 145, 95, 6, (30, 30, 30))
    # nose
    d.ellipse([125, 105, 135, 112], fill=(30, 30, 30))
    # tongue
    d.ellipse([127, 113, 133, 125], fill=(230, 100, 100))
    d.text((SIZE//2-28, 260), "Щенок", fill=(50,50,50), font=FONT)
    return img

def podjezd():
    img, d = new_canvas(200, 210, 220)
    # building
    rect(d, 40, 40, 250, 250, fill=(200, 200, 200), radius=4)
    # door
    d.arc([100, 160, 190, 250], 180, 360, fill=(100, 100, 120), width=5)
    rect(d, 100, 210, 190, 250, fill=(100, 100, 120))
    # steps
    rect(d, 90, 240, 200, 250, fill=(150, 150, 150))
    rect(d, 80, 250, 210, 255, fill=(150, 150, 150))
    # windows
    rect(d, 55, 55, 90, 90, fill=(180, 220, 255), radius=3)
    rect(d, 100, 55, 135, 90, fill=(180, 220, 255), radius=3)
    rect(d, 145, 55, 180, 90, fill=(180, 220, 255), radius=3)
    rect(d, 55, 100, 90, 135, fill=(180, 220, 255), radius=3)
    rect(d, 145, 100, 180, 135, fill=(180, 220, 255), radius=3)
    d.text((SIZE//2-35, 270), "Подъезд", fill=(50,50,50), font=FONT)
    return img

def syr():
    img, d = new_canvas(240, 230, 180)
    # cheese wedge
    triangle(d, [(60, 200), (220, 200), (220, 70)], fill=(255, 220, 80))
    # holes
    circle(d, 150, 160, 12, (240, 200, 70))
    circle(d, 180, 120, 8, (240, 200, 70))
    circle(d, 130, 120, 6, (240, 200, 70))
    circle(d, 170, 170, 7, (240, 200, 70))
    d.text((SIZE//2-16, 250), "Сыр", fill=(50,50,50), font=FONT)
    return img

def los():
    img, d = new_canvas(180, 200, 180)
    # body
    d.ellipse([100, 140, 200, 240], fill=(180, 150, 120))
    # head
    d.ellipse([80, 100, 140, 150], fill=(180, 150, 120))
    # antlers
    for ax, ay, bx, by in [(70,80,85,50),(85,50,105,40),(85,50,110,60),(160,80,145,50),(145,50,125,40),(145,50,120,60)]:
        d.line([(ax, ay), (bx, by)], fill=(120, 100, 70), width=4)
    # eye
    circle(d, 110, 115, 4, (30, 30, 30))
    d.text((SIZE//2-18, 260), "Лось", fill=(50,50,50), font=FONT)
    return img

def eskimo():
    img, d = new_canvas(220, 220, 240)
    # stick
    rect(d, 55, 130, 75, 270, fill=(180, 150, 100))
    # ice cream
    d.ellipse([40, 60, 90, 135], fill=(200, 150, 150))
    d.ellipse([40, 50, 90, 110], fill=(200, 100, 100))
    d.ellipse([40, 48, 90, 100], fill=(255, 200, 200))
    # chocolate layer
    d.ellipse([38, 110, 92, 130], fill=(80, 60, 40))
    # sprinkles
    for sx, sy in [(50,65),(65,58),(80,70),(55,85),(75,78),(60,95),(78,90)]:
        rect(d, sx, sy, sx+3, sy+6, fill=(255, 255, 100), radius=1)
    d.text((SIZE//2-32, 270), "Эскимо", fill=(50,50,50), font=FONT)
    return img

def yula():
    img, d = new_canvas(220, 210, 230)
    # top body
    triangle(d, [(140, 40), (115, 150), (165, 150)], fill=(200, 100, 100))
    triangle(d, [(140, 40), (115, 150), (140, 130)], fill=(200, 50, 50))
    # stripes
    d.ellipse([112, 100, 168, 130], fill=(255, 200, 50))
    d.ellipse([117, 110, 163, 125], fill=(255, 100, 100))
    # handle
    d.ellipse([140, 25, 170, 55], fill=(200, 100, 100))
    d.ellipse([145, 30, 165, 50], fill=(100, 100, 200))
    d.text((SIZE//2-16, 260), "Юла", fill=(50,50,50), font=FONT)
    return img

def yabloko():
    img, d = new_canvas(200, 230, 210)
    # apple body
    d.ellipse([80, 90, 200, 200], fill=(200, 80, 60))
    d.ellipse([85, 100, 195, 190], fill=(220, 60, 50))
    # leaf
    d.ellipse([160, 60, 200, 90], fill=(80, 180, 60))
    # stem
    d.line([(140, 80), (150, 55)], fill=(120, 90, 50), width=3)
    # shine
    d.ellipse([105, 105, 125, 125], fill=(255, 255, 255, 80))
    d.text((SIZE//2-32, 250), "Яблоко", fill=(50,50,50), font=FONT)
    return img

# ============== Map and generate ==============

FUNCS = {
    "арбуз": arbuz, "банан": banan, "волк": volk, "гриб": grib,
    "дом": dom, "енот": enot, "ёж": yozh, "жук": zhuk,
    "зебра": zebra, "ириска": iris, "йогурт": yogurt, "кот": kot,
    "лиса": lisa, "медведь": medved, "носорог": nosorog, "окно": okno,
    "пингвин": pingvin, "рыба": ryba, "сова": sova, "тигр": tigr,
    "утка": utka, "филин": filin, "хлеб": hleb, "цыпленок": cyplenok,
    "черепаха": cherepaha, "шапка": shapka, "щенок": shenok,
    "подъезд": podjezd, "сыр": syr, "лось": los,
    "эскимо": eskimo, "юла": yula, "яблоко": yabloko,
}

for name, func in FUNCS.items():
    out = os.path.join(OUT_DIR, f"{name}.png")
    if os.path.exists(out):
        print(f"  SKIP: {name}.png")
        continue
    img = func()
    img.save(out)
    print(f"  OK: {name}.png ({os.path.getsize(out)} bytes)")

print(f"\nDone! {len(FUNCS)} images in {OUT_DIR}")
