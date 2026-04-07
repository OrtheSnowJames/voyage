#!/usr/bin/env python3
import argparse
import pygame
import sys

def parse_size(s):
    w, h = s.lower().split("x")
    return int(w), int(h)

def eval_ratio(expr):
    try:
        return float(eval(expr, {"__builtins__": None}, {}))
    except Exception:
        raise argparse.ArgumentTypeError("Invalid ratio")

parser = argparse.ArgumentParser()
parser.add_argument("--size", type=parse_size, default="800x600")

group = parser.add_mutually_exclusive_group(required=True)
group.add_argument("--ratio", type=eval_ratio)
group.add_argument("--divisions", type=int)

parser.add_argument("--horizontal", action="store_true")
parser.add_argument("--vertical", action="store_true")

args = parser.parse_args()

width, height = args.size

pygame.init()
screen = pygame.display.set_mode((width, height))
pygame.display.set_caption("Divisions")

font = pygame.font.SysFont(None, 16)

draw_vertical = not args.horizontal or args.vertical
draw_horizontal = not args.vertical or args.horizontal

if args.ratio:
    step_x = width * args.ratio
    step_y = height * args.ratio
else:
    step_x = width / args.divisions
    step_y = height / args.divisions

def draw():
    screen.fill((255,255,255))

    # border
    pygame.draw.rect(screen, (0,0,0), (0,0,width,height), 1)

    # vertical
    if draw_vertical:
        x = step_x
        while x < width:
            pygame.draw.line(screen, (0,0,0), (x,0), (x,height), 1)

            text = font.render(f"{step_x:.1f}px", True, (0,0,0))
            screen.blit(text, (x+4, 4))

            x += step_x

    # horizontal
    if draw_horizontal:
        y = step_y
        while y < height:
            pygame.draw.line(screen, (0,0,0), (0,y), (width,y), 1)

            text = font.render(f"{step_y:.1f}px", True, (0,0,0))
            screen.blit(text, (4, y+4))

            y += step_y

    # size label
    label = font.render(f"{width}x{height}", True, (0,0,0))
    screen.blit(label, (width-80, height-20))

    pygame.display.flip()

draw()

while True:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            pygame.quit()
            sys.exit()