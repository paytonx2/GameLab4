"""
The Last Knight - level layout generator
สร้างไฟล์แผนที่ข้อความ tools/levels/level_0X.txt (1 ตัวอักษร = 1 ช่อง 32x32)
แล้ว tools/build_game.gd จะอ่านไฟล์เหล่านี้ไปสร้างฉากใน Godot

Legend
  #  พื้น (ป่า / ต้องสาป ตาม theme)    B  กำแพงอิฐปราสาท     =  แผ่นไม้ (ขึ้นจากด้านล่างได้)
  ~  ผิวน้ำ (ตกแต่ง)  w  น้ำลึก        P  จุดเกิดผู้เล่น      D  ประตูออกจากด่าน    C  ธงเช็คพอยต์
  c  เหรียญ  g  เพชร  h  หัวใจ  L  ชีวิตเพิ่ม  s  ยาเร่งความเร็ว  j  ยากระโดดสูง
  z  ซอมบี้  b  หมูป่าซอมบี้  f  แตนผี (บิน)  K  บอส  E  หลุมศพเกิดซอมบี้
  ^  หนาม  S  หอกพุ่ง  O  ลูกตุ้มหนาม (แขวนจากช่องนี้)  X  ใบเลื่อยเลื่อนซ้ายขวา  Y  ใบเลื่อยเลื่อนขึ้นลง
  F  กองไฟพ่นเปลว   M  แท่นเลื่อนซ้ายขวา  V  ลิฟต์ขึ้นลง  J  กระดานเด้ง  1/2  ประตูวาร์ป (คู่กัน)
  t  ต้นสน  T  ต้นสนมืด  d  ต้นไม้ตาย  r  หิน  R  หินมีมอส  m  เห็ด  k  ไม้กางเขน  o  ป้ายหลุมศพ  n  รั้วเหล็ก  u  พุ่มไม้
"""
import os

H = 20
HERE = os.path.dirname(os.path.abspath(__file__))


class Grid:
    def __init__(self, w):
        self.w = w
        self.g = [[" "] * w for _ in range(H)]
        self.labels = []

    def ground(self, x0, x1, top, ch="#", bottom=H - 1):
        for x in range(x0, x1 + 1):
            for y in range(top, bottom + 1):
                self.g[y][x] = ch

    def row(self, x0, x1, y, ch):
        for x in range(x0, x1 + 1):
            self.g[y][x] = ch

    def put(self, x, y, s):
        for i, ch in enumerate(s):
            if ch != " ":
                if x + i >= self.w:
                    print(f"  ! {ch} at ({x + i},{y}) outside the map")
                    continue
                if self.g[y][x + i] != " ":
                    print(f"  ! {ch} at ({x + i},{y}) overwrites '{self.g[y][x + i]}'")
                self.g[y][x + i] = ch

    def check(self):
        floor = set("PDCzbE^SFJtTdrRmkonuVK")
        for y in range(H):
            for x in range(self.w):
                ch = self.g[y][x]
                if ch in floor and (y + 1 >= H or self.g[y + 1][x] not in "#B="):
                    print(f"  ! {ch} at ({x},{y}) has no floor below")

    def water(self, x0, x1, top=17):
        for x in range(x0, x1 + 1):
            self.g[top][x] = "~"
            for y in range(top + 1, H):
                self.g[y][x] = "w"

    def label(self, x, y, text):
        self.labels.append((x, y, text))

    def save(self, name, **meta):
        print(name)
        self.check()
        path = os.path.join(HERE, "levels", name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf8") as f:
            for k, v in meta.items():
                f.write(f"{k}={v}\n")
            for x, y, t in self.labels:
                f.write(f"label={x};{y};{t}\n")
            f.write("map:\n")
            for r in self.g:
                f.write("".join(r).rstrip() + "\n")
        print("saved", path)


def level1():
    g = Grid(132)
    # start area
    g.ground(0, 18, 15)
    g.put(2, 14, "t  P   u   r  t")
    g.put(8, 12, "c c c")
    g.label(1, 9, "A / D = เดิน     Space = กระโดด\n(กดกลางอากาศอีกครั้ง = กระโดด 2 ชั้น)")
    g.water(19, 22)
    # first zombie
    g.ground(23, 42, 15)
    g.put(24, 14, "m  t    z    ^^ R t")
    g.label(25, 9, "X = ฟันดาบปล่อยคลื่นพลัง\nหรือกระโดดเหยียบหัวซอมบี้!")
    g.put(27, 12, "c c")
    # climb up
    g.ground(43, 57, 13)
    g.row(46, 50, 9, "=")
    g.put(48, 8, "g")
    g.put(44, 12, "c c  u S  S t")
    g.label(44, 5, "ระวังหอกที่พุ่งขึ้นจากพื้น")
    # moving platform over a gap
    g.water(58, 64, 17)
    g.put(58, 12, "M")
    g.put(60, 9, "c c c")
    g.ground(65, 86, 14)
    g.put(66, 13, "C  t    z   r  h    b")
    # jump pad up to a high ledge
    g.ground(87, 99, 10)
    g.put(84, 13, "J")
    g.label(80, 8, "กระดานเด้ง!")
    g.put(88, 9, "c c c  ^^  c  L")
    g.water(100, 103, 17)
    # final stretch
    g.ground(104, 131, 15)
    g.put(104, 14, "t  z    r   m  z   u  t   D")
    g.put(111, 11, "c c c")
    g.label(118, 9, "เข้าประตูเพื่อไปด่านต่อไป")
    return g


def level2():
    g = Grid(160)
    g.ground(0, 20, 15)
    g.put(2, 14, "P  t   u   z   r t")
    g.put(9, 12, "c c c")
    g.water(21, 24)
    g.ground(25, 44, 14)
    g.put(26, 13, " S  S  m  b   ^^ t")
    g.put(30, 9, "f")
    g.row(32, 37, 10, "=")
    g.put(33, 9, "c g c")
    # saw section
    g.ground(45, 70, 15)
    g.put(46, 14, "C   t      u      t    r")
    g.put(52, 12, "X")
    g.put(62, 12, "X")
    g.put(56, 10, "c c c")
    g.label(48, 7, "ใบเลื่อยเหล็กกลิ้งไปมา จังหวะให้ดี!")
    # elevator up the cliff
    g.ground(71, 74, 15)
    g.put(72, 14, "V")
    g.ground(75, 96, 7)
    g.put(76, 6, "s  t   z   c c c  u t")
    g.label(66, 3, "ยาสีฟ้า = วิ่งเร็วขึ้น 10 วินาที")
    # long jump over a valley with moving platforms
    g.water(97, 112, 17)
    g.put(98, 7, "M")
    g.put(106, 9, "M")
    g.put(100, 4, "c c c c c")
    g.ground(113, 126, 12)
    g.put(114, 11, "C   f  r  t 1")
    # portal shortcut through a stone wall too high to jump
    g.ground(127, 159, 15)
    g.ground(127, 131, 2)
    g.put(134, 14, "2")
    g.put(136, 14, "h  z  m  E  ^^  z  t D")
    g.put(150, 11, "c c c")
    g.label(117, 6, "ประตูวาร์ปพาข้ามกำแพงหิน")
    return g


def level3():
    g = Grid(170)
    g.ground(0, 18, 15)
    g.put(2, 14, "P  d  k  o  n    k")
    g.put(9, 12, "c c c")
    g.label(1, 8, "สุสานต้องสาป... ซอมบี้คลานขึ้นมาจากหลุมศพ")
    g.ground(19, 40, 15)
    g.put(20, 14, "o  E   k   F     d   z  o")
    g.put(24, 11, "f")
    g.row(30, 35, 11, "=")
    g.put(31, 10, "c g c")
    # pendulum corridor
    g.ground(41, 66, 15)
    g.ground(41, 66, 0, bottom=4)
    g.put(46, 5, "O       O       O")
    g.put(42, 14, "C   c c   c c   c c   k  j")
    g.label(43, 8, "ลูกตุ้มหนามแกว่ง หลบให้พ้น!")
    # jump potion -> high ledges
    g.ground(67, 70, 15)
    g.ground(71, 80, 10)
    g.put(72, 9, "c c  z  d")
    g.water(81, 90, 17)
    g.row(84, 87, 9, "=")
    g.put(85, 8, "h")
    g.ground(91, 108, 12)
    g.put(92, 11, "F  o  b  k   F  C")
    g.put(97, 8, "f")
    # elevator shaft + fire
    g.ground(109, 112, 15)
    g.put(110, 14, "V")
    g.ground(113, 130, 6)
    g.put(114, 5, "c c c ^^ z ^^ t L")
    g.water(131, 138, 17)
    g.put(131, 6, "M")
    g.ground(139, 169, 13)
    g.put(140, 12, "k  E   o   z   F  d  b   k   D")
    g.put(150, 9, "c c c")
    return g


def level4():
    g = Grid(150)
    g.ground(0, 16, 15, "B")
    g.put(2, 14, "P   n   n   r")
    g.label(1, 8, "ปราสาทของเนโครแมนเซอร์\nจบคำสาปนี้ให้ได้!")
    g.put(8, 12, "c c c")
    # trap gauntlet
    g.ground(17, 44, 15, "B")
    g.ground(17, 44, 0, "B", bottom=3)
    g.put(19, 14, "S  S  S  F   ^^^  F  S  S")
    g.put(24, 4, "O          O")
    g.put(32, 11, "Y")
    g.put(22, 11, "c   c   c   c   c")
    g.water(45, 50)
    g.put(45, 12, "M")
    g.ground(51, 66, 13, "B")
    g.put(52, 12, "C  z  h   f   z  b")
    g.row(56, 61, 9, "=")
    g.put(57, 8, "g s g")
    # tower climb
    g.ground(67, 70, 13, "B")
    g.put(68, 12, "J")
    g.ground(71, 80, 8, "B")
    g.put(72, 7, "c  z   c  L")
    g.water(81, 86)
    g.put(81, 8, "M")
    g.ground(87, 92, 10, "B")
    g.put(88, 9, "C  h")
    g.label(84, 3, "ลานต่อสู้สุดท้าย")
    # boss arena (walls on both sides)
    g.ground(93, 149, 15, "B")
    g.ground(93, 94, 0, "B", bottom=8)
    g.ground(148, 149, 0, "B", bottom=14)
    g.row(100, 105, 11, "=")
    g.row(112, 117, 9, "=")
    g.row(124, 129, 11, "=")
    g.row(136, 141, 9, "=")
    g.put(102, 10, "h")
    g.put(138, 8, "h")
    g.put(120, 14, "K")
    g.put(97, 14, "n  r")
    g.put(144, 14, "D")
    return g


if __name__ == "__main__":
    level1().save("level_01.txt", title="บทที่ 1 : ชายป่าแห่งรุ่งอรุณ", subtitle="Dawn Forest", theme="forest", bg=1,
                  music="music_forest")
    level2().save("level_02.txt", title="บทที่ 2 : ป่าสนยามพลบค่ำ", subtitle="Twilight Woods", theme="forest", bg=2,
                  music="music_forest")
    level3().save("level_03.txt", title="บทที่ 3 : สุสานต้องสาป", subtitle="Cursed Graveyard", theme="cursed", bg=3,
                  music="music_cursed")
    level4().save("level_04.txt", title="บทที่ 4 : ปราสาทเนโครแมนเซอร์", subtitle="Necromancer's Keep", theme="cursed",
                  bg=4, music="music_boss")
