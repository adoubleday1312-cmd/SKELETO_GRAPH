import json, re, csv

records = json.load(open('path_records.json'))
outline = [r for r in records if r['role']=='outline']
byid = {r['id']: r for r in records}
MID = 208.5

assigned = {}
confidence = {}

def add(ids, name, conf='high'):
    for i in ids:
        pid = f"lh_path_{i:04d}"
        assigned[pid] = name
        confidence[pid] = conf

# ---- SKULL ----
add([583], 'cranium')
add([562], 'orbit_R'); add([563], 'orbit_L')
add([565,569,568], 'nasal_bone_R', 'medium'); add([566,570,571], 'nasal_bone_L', 'medium')
add([572], 'zygomatic_R'); add([577], 'zygomatic_L')
add([549], 'maxilla_R'); add([550], 'maxilla_L')
add([511], 'mandible')
add([543,541,542], 'temporal_bone_R', 'medium')
add([545,585,546,544], 'temporal_bone_L', 'medium')

# ---- TEETH (grouped per user's choice) ----
add([596,597,598,599,600,601,602,603,604,605,606,607], 'teeth_upper')
add([527,528,529,530,531,532,533,534,535,536,537,538,539,540], 'teeth_lower')

# ---- CERVICAL SPINE ----
cervical_pairs = [(508,507,'C1'),(495,494,'C2'),(486,485,'C3'),(475,467,'C4'),
                  (466,463,'C5'),(454,453,'C6'),(450,449,'C7')]
for a,b,lvl in cervical_pairs:
    add([a,b], f'cervical_vertebra_{lvl}', 'medium')
add([448], 'cervical_vertebra_C7', 'medium')

# ---- SHOULDER GIRDLE ----
add([623], 'clavicle_R'); add([625], 'clavicle_L')
add([613], 'scapula_R_acromion', 'medium'); add([612], 'scapula_L_acromion', 'medium')
add([427], 'scapula_R_coracoid', 'medium'); add([434], 'scapula_L_coracoid', 'medium')
add([220], 'scapula_R'); add([215], 'scapula_L')
add([662,653,652], 'humerus_R')
add([629,628], 'humerus_L')
add([225], 'acromioclavicular_joint_R', 'medium'); add([226], 'acromioclavicular_joint_L', 'medium')
add([610,618], 'sternoclavicular_joint_R', 'medium'); add([609,611], 'sternoclavicular_joint_L', 'medium')

# ---- STERNUM ----
add([619], 'sternum_manubrium')
add([159,896], 'sternum_body')
add([153], 'sternum_xiphoid_process')

# ---- COSTAL CARTILAGE (rib-sternum junctions) ----
add([444,446], 'costal_cartilage_R', 'low')
add([445,447], 'costal_cartilage_L', 'low')

# ---- RIBS ----
ribs_R = [440,417,412,399,391,378,374,362,358,350,353]
for n,i in enumerate(ribs_R, start=1):
    add([i], f'rib_R_{n}', 'medium' if n<=9 else 'low')
ribs_L = [441,422,407,403,395,387,383,370,366,347,355]
for n,i in enumerate(ribs_L, start=1):
    add([i], f'rib_L_{n}', 'medium' if n<=9 else 'low')
add([443], 'rib_R_lower_margin_uncertain', 'low')
add([442], 'rib_L_lower_margin_uncertain', 'low')

# ---- THORACIC VERTEBRAE ----
thoracic_ids = [254,145,343,253,328,252,336,144,321,291,306,305,290,292,293,255,280,281,257,269,270,256,258,251]
thoracic_ids_sorted = sorted(thoracic_ids, key=lambda i: byid[f'lh_path_{i:04d}']['bbox'][5])
groups = []
cur = []
prev_cy = None
for i in thoracic_ids_sorted:
    cy = byid[f'lh_path_{i:04d}']['bbox'][5]
    if prev_cy is not None and (cy - prev_cy) > 3.5:
        groups.append(cur); cur = []
    cur.append(i)
    prev_cy = cy
if cur: groups.append(cur)
for n, g in enumerate(groups[:12], start=1):
    add(g, f'thoracic_vertebra_T{n}', 'low')
for extra_n, g in enumerate(groups[12:], start=1):
    add(g, f'lumbar_vertebra_L{extra_n}', 'low')

# ---- SACRUM / COCCYX / PELVIS ----
add([234,228], 'sacrum', 'medium')
add([203,176], 'pelvis', 'low')
add([188], 'pelvis_R_iliac_crest', 'medium'); add([195], 'pelvis_L_iliac_crest', 'medium')
add([204], 'coccyx', 'medium')

# ---- FOREARM (shape-confirmed) ----
add([669], 'radius_R'); add([676], 'ulna_R')
add([639], 'radius_L'); add([644], 'ulna_L')
add([667], 'humerus_R_distal_condyle', 'medium')
add([636], 'humerus_L_distal_condyle', 'medium')

# ---- LEGS ----
add([187], 'patella_R_ligament', 'medium'); add([909], 'patella_R')
add([202], 'patella_L_ligament', 'medium'); add([912], 'patella_L')
add([168], 'tibia_R'); add([164], 'fibula_R')
add([901], 'tibia_L'); add([897], 'fibula_L')
add([183], 'femur_R', 'medium'); add([192], 'femur_L', 'medium')

print("Explicit assignments so far:", len(assigned))

# ---- Catch-all: hand / foot groups by position ----
remaining = [r for r in outline if r['id'] not in assigned]
print("Remaining before catchall:", len(remaining))
for r in remaining:
    cx, cy = r['bbox'][4], r['bbox'][5]
    if cy < 560:  # hand region (arm/hand y-range, below elbow)
        side = 'R' if cx < MID else 'L'
        add([int(r['id'].split('_')[-1])], f'hand_{side}', 'grouped')
    elif cy > 800:  # foot region
        side = 'R' if cx < MID else 'L'
        add([int(r['id'].split('_')[-1])], f'foot_{side}', 'grouped')
    else:
        print("UNCLASSIFIED:", r['id'], r['bbox'])

print("Total assigned:", len(assigned), "of", len(outline))

# ---- Write CSV ----
rows = []
for r in outline:
    pid = r['id']
    name = assigned.get(pid, 'UNASSIGNED')
    conf = confidence.get(pid, 'n/a')
    minx,miny,maxx,maxy,cx,cy = r['bbox']
    rows.append([pid, name, conf, round(cx,1), round(cy,1)])

rows.sort(key=lambda x: x[3])  # rough left-to-right; will resort by name later
with open('bone_accession.csv','w',newline='') as f:
    w = csv.writer(f)
    w.writerow(['path_id','bone_name','confidence','centroid_x','centroid_y'])
    for row in sorted(rows, key=lambda r: r[1]):
        w.writerow(row)

json.dump({'assigned':assigned,'confidence':confidence}, open('assigned_final.json','w'))
print("CSV written.")
