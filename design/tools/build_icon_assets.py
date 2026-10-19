"""Build the original SVG icon study, exports, review boards and PDF. No network access."""
from pathlib import Path
import hashlib, json, shutil, subprocess, xml.etree.ElementTree as ET
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import ImageReader

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'icon'
TEAL, CREAM, DARK, MINT = '#24675D', '#F7F5EE', '#172D29', '#B7DFCB'

def path(d, fill='@', **attrs):
    extra = ' '.join(f'{k.replace("_", "-")}="{v}"' for k,v in attrs.items())
    return f'<path d="{d}" fill="{fill}" {extra}/>'
def circle(x,y,r,fill='@'):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"/>'
def stroke(d,w=52):
    return path(d,'none',stroke='@',stroke_width=w,stroke_linecap='round',stroke_linejoin='round')
bubble = 'M512 218 C690 218 814 328 814 478 C814 626 690 734 512 734 L352 812 L371 708 C269 668 210 583 210 478 C210 328 334 218 512 218 Z'
ring = path(bubble)+path('M512 278 C368 278 270 360 270 478 C270 597 368 674 512 674 C656 674 754 597 754 478 C754 360 656 278 512 278 Z','~')
plate = path('M512 196 A298 298 0 1 1 369 755 L239 805 L270 677 A298 298 0 0 1 512 196 Z')+circle(512,494,230,'~')+circle(512,494,158)+circle(512,494,106,'~')
leaf = path('M388 588 C315 438 425 344 647 337 C664 538 564 637 388 588 Z')
bowl = path('M234 462 H790 C767 623 664 716 512 716 C360 716 257 623 234 462 Z')
final_body = 'M224 466 H800 C782 561 738 632 672 679 L696 790 L572 724 C553 727 532 729 512 729 C355 729 249 626 224 466 Z'
final_rim = 'M248 350 C408 310 616 310 776 350 C802 356 816 376 810 397 C804 418 784 428 758 422 C608 386 416 386 266 422 C240 428 220 418 214 397 C208 376 222 356 248 350 Z'
BOWL = path(final_body)+path(final_rim)
CONCEPTS = [
('01','Bowl in conversation',ring + path('M350 477 H674 C654 570 600 613 512 613 C424 613 370 570 350 477 Z'), 'Literal food + conversation; nested shapes cost detail at small sizes.'),
('02','Talking plate',plate,'A familiar plate becomes a speech bubble; strong silhouette, more generic.'),
('03','Leaf in a bubble',ring+leaf,'Soft and calm; risks implying plant-only eating.'),
('04','Steam conversation',path('M428 204 H607 Q677 204 677 274 V319 Q677 389 607 389 H544 L468 435 V389 H428 Q358 389 358 319 V274 Q358 204 428 204 Z')+bowl,'Warm meal and spoken log; separated elements feel more illustrative.'),
('05','Conversation bowl',BOWL,'Food and conversation in one silhouette; no diet, metric or security promise.'),
('06','Seed exchange',path(bubble)+path('M398 590 C321 453 424 350 640 342 C654 535 562 626 398 590 Z','~'),'A soft organic alternative; leaf/seed ambiguity weakens the logging story.'),
('07','Shared table',circle(512,512,298)+circle(512,512,220,'~')+path('M369 399 H655 V489 Q655 609 535 609 H491 L404 662 V591 Q369 558 369 489 Z'),'Plate enclosing a conversation; dense at the smallest size.'),
('08','Fork conversation',ring+stroke('M442 362 V430 Q442 474 486 474 Q530 474 530 430 V362 M486 362 V600',44),'Selected by the owner: a familiar eating cue inside a conversation bubble.'),
('09','Quiet bowl',bowl+stroke('M403 369 C366 334 445 294 408 250 M584 369 C547 334 626 294 589 250',48),'Warm, uncomplicated meal symbol; loses the distinctive conversation cue.'),
('10','Personal table',path('M512 210 L784 326 V516 C784 662 672 755 512 818 C352 755 240 662 240 516 V326 Z')+path('M342 440 H682 C667 558 603 626 512 626 C421 626 357 558 342 440 Z','~'),'Enclosure suggests ownership; shield can overstate security, so not selected.'),
]
REFINEMENTS = [
('r1','Plate, simplified',path('M512 216 A282 282 0 1 1 375 745 L250 792 L280 668 A282 282 0 0 1 512 216 Z')+circle(512,498,212,'~')+circle(512,498,131), '02 with fewer rings; bold but still reads as a generic messaging brand.'),
('r2','Bowl, flat rim',path(final_body)+path('M244 350 H780 Q812 350 812 382 Q812 414 780 414 H244 Q212 414 212 382 Q212 350 244 350 Z'),'05 with a straight rim; smallest-size clarity, less warmth and depth.'),
('r3','Bowl, curved rim',BOWL,'05 with a separated curved rim; retained as an explored alternative.'),
]

# Preserve the selected conversation ring; center the fork-and-knife pair in its interior.
inner_bubble = 'M512 278 C368 278 270 360 270 478 C270 597 368 674 512 674 C656 674 754 597 754 478 C754 360 656 278 512 278 Z'
FORK = stroke('M398 358 V426 Q398 470 442 470 Q486 470 486 426 V358 M442 358 V594',44)
KNIFE = path('M644 336 Q648 336 648 344 V594 Q648 616 626 616 Q604 616 604 594 V500 H570 C566 424 590 366 632 340 Q640 336 644 336 Z')
FINAL = path(bubble + ' ' + inner_bubble, fill_rule='evenodd') + FORK + KNIFE
REFINEMENTS.append(('r4','Fork + knife conversation',FINAL,'Owner-requested refinement: fork and kitchen knife centered together inside the selected bubble.'))

def svg(mark,bg=TEAL,fg=CREAM):
    # Exploration cutouts use background paint; the selected mark uses an even-odd hole.
    background = f'<rect width="1024" height="1024" fill="{bg}"/>' if bg else ''
    content=mark.replace('@',fg).replace('~',bg or '#000000')
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{background}{content}</svg>\n'

def render(source,dest,size=1024):
    subprocess.run(['rsvg-convert','--width',str(size),'--height',str(size),'-o',str(dest),str(source)],check=True)

for folder in ('concepts','refinements','previews','exports','layers'):
    (OUT/folder).mkdir(parents=True,exist_ok=True)
for number,name,mark,reason in CONCEPTS+REFINEMENTS:
    folder='concepts' if number.isdigit() else 'refinements'
    target=OUT/folder/f'{number}-{name.lower().replace(",", "").replace(" ", "-")}.svg'
    target.write_text(svg(mark))
    render(target,target.with_suffix('.png'))

for name,bg,fg in [('app-icon',TEAL,CREAM),('app-icon-dark',DARK,MINT),('app-icon-tinted',None,'#808080')]:
    target=OUT/f'{name}.svg'; target.write_text(svg(FINAL,bg,fg))
    render(target,OUT/'exports'/f'{name}-1024.png')
    for size in (180,60,29): render(target,OUT/'previews'/f'{name}-{size}.png',size)
# Optional separated sources for a later Icon Composer workflow, not a compiled .icon bundle.
(OUT/'layers'/'foreground.svg').write_text(svg(FINAL,None,CREAM))
(OUT/'layers'/'background.svg').write_text(svg('',TEAL,CREAM))

# Review HTML: genuine requested CSS pixel sizes including full 1024, scrollable on smaller displays.
html=['<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Healthy Eating icon study</title><style>body{margin:40px;font:16px system-ui;background:#f7f5ee;color:#172d29}h1{font-size:42px}h2{margin-top:56px}.wall{padding:32px;margin:20px 0;overflow:auto;border-radius:18px}.light{background:#e7e7e2}.dark{background:#182223;color:#f7f5ee}.sizes{display:flex;align-items:center;gap:28px;width:max-content}.sample{display:flex;flex-direction:column;align-items:center;gap:14px}.sample svg{display:block;clip-path:inset(0 round 22%)}p{max-width:760px;line-height:1.6}</style><h1>Food, in conversation.</h1><p>Healthy Eating / app icon study / 18 October 2026. Ten concepts and four refinements. R4 adds a kitchen knife to selected concept 08 and centers both utensils, as requested by the owner. Icons below are shown at actual CSS pixel sizes. Rounded masks are illustrative previews only; source assets remain square.</p>']
for number,name,mark,reason in CONCEPTS+REFINEMENTS:
    html.append(f'<h2>{number.upper()} / {name}</h2><p>{reason}</p>')
    for wall in ('light','dark'):
        html.append(f'<section class="wall {wall}"><h3>{wall.title()} wallpaper</h3><div class="sizes">')
        for size in (1024,180,60,29):
            inline=svg(mark).replace('width="1024" height="1024" viewBox',f'width="{size}" height="{size}" viewBox',1)
            html.append(f'<div class="sample">{inline}<span>{size} px</span></div>')
        html.append('</div></section>')
html.append('</html>'); (OUT/'review.html').write_text('\n'.join(html))

# Publication-quality concept book: master artwork fitted; small-size checks native at 1 px = 1 pt.
W,H=960,720
pdf=canvas.Canvas(str(OUT/'concepts.pdf'),pagesize=(W,H))
pdf.setTitle('Healthy Eating - App icon exploration');pdf.setAuthor('Healthy Eating')
def text(x,y,s,size=12,color=DARK,font='Helvetica'):
    pdf.setFillColor(HexColor(color));pdf.setFont(font,size);pdf.drawString(x,y,s)
def base(k,title,sub):
    pdf.setFillColor(HexColor(CREAM));pdf.rect(0,0,W,H,fill=1,stroke=0)
    text(48,675,'HEALTHY EATING / ICON STUDY',10,TEAL,'Helvetica-Bold')
    text(48,625,title,32,DARK,'Helvetica-Bold');text(48,593,sub,12)
    text(48,25,'18 OCT 2026 / ORIGINAL VECTOR ART / MIT / CURRENT: R4 / FORK + KNIFE',9)
    text(875,25,f'{k:02d}',10)
def masked_img(img):
    im=Image.open(img).convert('RGBA');mask=Image.new('L',im.size);d=ImageDraw.Draw(mask);d.rounded_rectangle((0,0,1024,1024),radius=225,fill=255);im.putalpha(mask);return im
def draw_icon(img,x,y,size,masked=False):
    source=ImageReader(masked_img(img) if masked else str(img));pdf.drawImage(source,x,y,size,size,mask='auto')
base(1,'Food, in conversation.','App icon exploration for a private, honest nutrition dashboard.')
for i,(num,name,mark,reason) in enumerate(CONCEPTS):
    col,row=i%5,i//5;x=48+col*176;y=354-row*226
    file=next((OUT/'concepts').glob(f'{num}-*.png'));draw_icon(file,x,y,144,True)
    text(x,y-24,f'{num} / {name}',10,DARK,'Helvetica-Bold')
text(48,83,'Current: R4 / Fork + knife conversation. Selected concept 08 with the requested centered utensil pair.',12)
pdf.showPage()
for page,(num,name,mark,reason) in enumerate(CONCEPTS+REFINEMENTS,2):
    base(page,f'{num.upper()} / {name}',reason)
    folder='concepts' if num.isdigit() else 'refinements';img=next((OUT/folder).glob(f'{num}-*.png'))
    for idx,wall in enumerate(('#E7E7E2','#182223')):
        x=48+idx*440
        pdf.setFillColor(HexColor(wall));pdf.roundRect(x,96,424,466,16,fill=1,stroke=0)
        color=DARK if idx==0 else CREAM
        text(x+20,532,'LIGHT WALLPAPER' if idx==0 else 'DARK WALLPAPER',10,color,'Helvetica-Bold')
        draw_icon(img,x+117,336,190,True);text(x+117,316,'1024 px master / fitted to page',10,color)
        for xx,size in ((20,180),(225,60),(337,29)):
            draw_icon(img,x+xx,120,size,True);text(x+xx,101,f'{size} px',10,color)
    text(48,66,'Native-size 1024 / 180 / 60 / 29 px comparisons are in review.html. Preview masks are approximate.',10)
    pdf.showPage()
base(16,'One mark. Three appearances.','R4 / Fork + knife conversation / requested by the owner on 18 October 2026.')
for i,(name,label) in enumerate([('app-icon','Default'),('app-icon-dark','Dark'),('app-icon-tinted','Tint source')]):
    x=48+i*296
    if i==2:
        pdf.setFillColor(HexColor('#FFFFFF'));pdf.rect(x,256,264,264,fill=1,stroke=0)
        text(x,236,'Transparent background / gray mark',10)
    draw_icon(OUT/'exports'/f'{name}-1024.png',x,256,264,i!=2)
    text(x,219,label,18,DARK,'Helvetica-Bold')
text(48,166,'Fork and kitchen knife share a centered footprint inside the original conversation bubble.',12)
text(48,140,'Default and dark files are opaque full-bleed squares. The tinted source intentionally retains alpha.',12)
text(48,114,'No type, gradients, embedded fonts, third-party graphics or baked corner masks.',12)
text(48,71,'Xcode/device appearance checks remain pending: this repository has no app target yet.',11)
pdf.showPage();pdf.save()

# Standalone attachment preview at 1440x860, derived directly from SVG raster exports.
board=Image.new('RGB',(1440,860),CREAM);d=ImageDraw.Draw(board)
fontpath='/System/Library/Fonts/Helvetica.ttc'
def font(size): return ImageFont.truetype(fontpath,size)
d.text((60,44),'Food, in conversation.',font=font(48),fill=DARK)
d.text((62,110),'Healthy Eating  /  R4 Fork + knife conversation  /  18 Oct 2026',font=font(21),fill=TEAL)
for i,(name,label) in enumerate([('app-icon','Default'),('app-icon-dark','Dark'),('app-icon-tinted','Tint source / transparent')]):
    x=60+i*460
    im=Image.open(OUT/'exports'/f'{name}-1024.png').convert('RGBA').resize((400,400),Image.Resampling.LANCZOS)
    if i==2:
        for a in range(0,400,20):
            for b in range(0,400,20):d.rectangle((x+a,180+b,x+a+19,180+b+19),fill='#E0E3DF' if (a+b)//20%2 else '#FFFFFF')
    board.paste(im,(x,180),im)
    d.text((x,604),label,font=font(25),fill=DARK)
    for j,s in enumerate((180,60,29)):
        small=Image.open(OUT/'previews'/f'{name}-{s}.png').convert('RGBA');sx=x+(0,220,334)[j]
        board.paste(small,(sx,654),small);d.text((sx,836),str(s)+' px',font=font(14),fill=DARK)
board.save(OUT/'previews'/'selected.png')

# Machine checks are artifact validation, not application tests.
checks=[]
for file in sorted(OUT.rglob('*.svg')):
    root=ET.parse(file).getroot();assert root.attrib['viewBox']=='0 0 1024 1024'
    assert root.attrib['width']==root.attrib['height']=='1024'
    tags={n.tag.split('}')[-1] for n in root.iter()};assert tags <= {'svg','rect','path','circle'}
    assert not any('href' in key for n in root.iter() for key in n.attrib)
    checks.append(str(file.relative_to(ROOT)))
for name in ('app-icon','app-icon-dark'):
    im=Image.open(OUT/'exports'/f'{name}-1024.png').convert('RGBA');assert im.size==(1024,1024);assert im.getchannel('A').getextrema()==(255,255)
im=Image.open(OUT/'exports'/'app-icon-tinted-1024.png').convert('RGBA');assert im.getchannel('A').getextrema()==(0,255)
assert all(r==g==b for r,g,b,a in im.get_flattened_data() if a)
# The bubble interior must remain a real hole, not a black patch on the tinted source.
assert im.getpixel((540,480))[3] == 0
assert im.getpixel((442,550))[3] == 255
assert im.getpixel((626,550))[3] == 255
# The utensils' visible bounds have the same center as the bubble interior.
utensil_source=OUT/'previews'/'utensil-alignment.svg'
utensil_source.write_text(svg(FORK+KNIFE,None,'#808080'))
render(utensil_source,utensil_source.with_suffix('.png'))
bounds=Image.open(utensil_source.with_suffix('.png')).getchannel('A').getbbox()
assert bounds==(376,336,648,616), bounds
assert ((bounds[0]+bounds[2])/2,(bounds[1]+bounds[3])/2)==(512,476)
utensil_source.unlink();utensil_source.with_suffix('.png').unlink()
for name in ('app-icon','app-icon-dark','app-icon-tinted'):
    nodes=list(ET.parse(OUT/f'{name}.svg').getroot())
    assert nodes[-3].attrib['fill-rule']=='evenodd'
    assert nodes[-3].attrib['d']==bubble+' '+inner_bubble
    assert nodes[-2].attrib['stroke-width']=='44'
from pypdf import PdfReader
assert len(PdfReader(OUT/'concepts.pdf').pages)==16
(OUT/'validation.json').write_text(json.dumps({'selected_concept':'R4 / Fork + knife conversation','utensil_bounds':bounds,'utensil_center':[512,476],'owner_selected_on':'2026-10-18','tinted_bubble_interior_transparent':True,'svg_files_checked':checks,'pdf_pages':16,'master_size':[1024,1024],'default_and_dark_opaque':True,'tinted_has_transparency_and_grayscale':True,'application_build':'Not available: no Xcode project','device_validation':'Pending'},indent=2)+'\n')
print(f'Built and validated {len(checks)} SVGs; 16-page PDF; PNGs; HTML review.')
