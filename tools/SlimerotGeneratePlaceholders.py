"""Regenerate Slimerot's original, replaceable SVG and PCM placeholder assets.

Python standard library only. All shapes/melodies are authored here, no downloads.
Run from any directory: python tools/SlimerotGeneratePlaceholders.py
"""
from pathlib import Path
import colorsys
import math
import re
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets' / 'art'
AUDIO = ROOT / 'assets' / 'audio'


def svg(group, name, body, size=256):
    folder = ART / group
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f'Slimerot_{name}.svg').write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 256 256">'
        '<g stroke="#223347" stroke-width="7" stroke-linecap="round" stroke-linejoin="round">'
        f'{body}</g></svg>\n', encoding='utf-8')


def ellipse(cx, cy, rx, ry, color, stroke='none'):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{color}" stroke="{stroke}"/>'


def path(d, fill, width=7, stroke='#223347'):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'


def rect(x, y, w, h, fill, r=10):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}"/>'


def face(expression=0):
    if expression % 4 == 2:
        eyes = path('M87 137 L104 132 M151 132 L169 137', 'none', 9)
    elif expression % 4 == 3:
        eyes = ellipse(96, 137, 11, 14, '#223347') + ellipse(160, 137, 11, 14, '#223347')
    else:
        eyes = ellipse(96, 137, 9, 12, '#223347') + ellipse(160, 137, 9, 12, '#223347')
    return eyes + ellipse(91, 131, 3, 4, '#ffffff') + ellipse(155, 131, 3, 4, '#ffffff') + path('M112 163 Q128 178 144 163', 'none', 6) + ellipse(74, 155, 12, 6, '#f99ba5') + ellipse(182, 155, 12, 6, '#f99ba5')


def blob(color, accent, expression=0, shape=0):
    shapes = [
        'M39 177 C43 143 48 102 82 86 C101 51 147 53 170 81 C203 96 212 133 217 168 C233 212 193 222 168 209 C145 229 116 221 102 211 C55 227 22 208 39 177Z',
        'M41 172 C47 125 37 87 86 81 C105 49 151 50 173 84 C215 87 215 138 215 174 C236 212 201 225 172 211 C143 230 113 220 100 211 C58 232 19 212 41 172Z',
        'M35 175 C45 143 42 114 70 97 C81 65 103 63 129 69 C156 52 183 76 186 98 C215 115 211 146 222 180 C234 215 195 226 169 211 C145 229 111 219 95 214 C46 227 16 204 35 175Z',
    ]
    return path(shapes[shape % 3], color) + ellipse(74, 108, 13, 8, '#ffffff', 'none') + path('M53 188 Q78 205 94 191 M168 189 Q190 202 204 184', 'none', 5, accent) + face(expression)


# Deliberately distinct prop silhouettes: each roster member remains a slime.
props = [
    rect(105, 51, 52, 37, '#c58b54') + path('M172 153 L221 97 L234 107 L188 167Z', '#b78050'),
    path('M70 90 Q55 38 80 32 Q107 43 104 85 M151 81 Q153 26 178 34 Q190 62 180 102', '#9bd686') + ellipse(128, 66, 31, 16, '#e7f3a5', '#223347'),
    path('M56 104 Q68 30 128 51 Q174 18 204 79 Q167 64 155 101 Q124 72 97 104Z', '#ffe072'),
    ellipse(128, 92, 51, 16, '#f2dbb7', '#223347') + rect(90, 38, 77, 50, '#fff0de') + path('M170 45 C212 39 210 82 171 77', 'none') + path('M57 191 Q128 155 204 195 L186 215 Q128 202 67 216Z', '#f5a7ce'),
    rect(78, 55, 100, 36, '#e9d6b9') + path('M64 111 L188 111 L176 146 L82 146Z', '#4b4a63') + path('M174 176 L224 116 L232 126 L192 190Z', '#d9e4ec'),
    path('M114 81 L143 28 L153 90Z', '#68cadb') + rect(34, 197, 66, 23, '#f8f8e6') + rect(155, 198, 67, 23, '#f8f8e6'),
    path('M65 99 C12 57 13 146 54 144 M191 99 C244 57 243 146 202 144', '#b9d7a5') + path('M119 164 Q100 205 132 208 Q153 208 145 190', 'none', 15, '#9cbc8e') + path('M121 79 L111 34 L128 55 L145 30 L143 80', '#77b784'),
    rect(89, 38, 79, 65, '#d5edf0') + path('M96 70 H161 M151 49 V58 M151 82 V92', 'none', 5) + path('M64 106 Q37 74 51 66 M190 106 Q218 74 204 65', 'none', 9, '#b9e0dd'),
    path('M89 91 L49 49 L72 42 L129 79 L179 42 L204 49 L166 93Z', '#87b69a') + path('M52 159 L39 144 L34 165 M202 159 L217 144 L223 165', '#fff4d0'),
    path('M53 121 L18 97 L28 149 L50 162 M203 121 L238 97 L228 149 L206 162', '#f6b490') + path('M98 85 L77 57 M154 85 L178 57', 'none', 6) + ellipse(71, 53, 9, 10, '#ffd999', '#223347') + ellipse(184, 53, 9, 10, '#ffd999', '#223347'),
    path('M57 107 L14 75 L26 137 L57 159 M199 107 L242 75 L230 137 L199 159', '#e4edf1') + path('M111 157 L130 181 L146 157Z', '#ffb05f') + path('M88 79 L83 57 H173 L168 82', '#9dbfd4'),
    path('M81 82 L70 43 M173 82 L184 43', 'none', 11, '#bcb0e8') + ellipse(69, 36, 12, 12, '#f4d875', '#223347') + ellipse(185, 36, 12, 12, '#f4d875', '#223347') + ellipse(74, 181, 11, 14, '#dca764') + ellipse(179, 181, 13, 11, '#dca764'),
    path('M92 85 L70 40 L110 55 L126 24 L142 54 L183 36 L163 89Z', '#82bd83') + path('M68 184 L88 202 M177 182 L161 202', 'none', 5, '#d89958'),
    path('M42 88 L84 69 L97 35 L159 35 L174 68 L219 89Z', '#c3a17a') + path('M61 123 Q126 106 196 123 L184 152 Q128 139 71 154Z', '#3f3d56') + rect(111, 173, 34, 19, '#fff2d7', 2),
    path('M64 105 Q29 69 42 45 Q72 48 89 93 M166 93 Q184 48 214 45 Q229 72 192 105', '#f6e8c7') + '<ellipse cx="128" cy="173" rx="118" ry="30" fill="none" stroke="#f5cc7a" stroke-width="12" transform="rotate(-18 128 173)"/>',
    path('M96 90 L93 43 Q102 21 114 42 L117 84 M146 83 L149 44 Q160 21 169 43 L164 94', '#8ac797') + path('M57 117 L46 110 M194 117 L209 108 M126 78 V66', 'none', 4, '#e0efbc'),
    path('M79 101 Q47 54 86 48 Q120 36 129 75 Q153 33 182 52 Q214 72 176 106Z', '#f39ba2') + path('M123 70 L119 43 L147 30', 'none', 9, '#97bd74') + path('M91 160 L101 149 L112 163 M146 163 L159 149 L168 160', '#fff6da', 4),
    path('M54 116 Q48 60 89 70 Q127 30 166 67 Q206 59 207 116Z', '#b6c5d5') + rect(70, 98, 118, 18, '#77879d', 4) + path('M37 161 L17 181 L47 193 M216 161 L239 181 L208 193', '#d4deea'),
    path('M52 180 Q6 211 38 222 Q62 226 75 202 M92 198 Q64 240 102 231 L118 210 M162 202 Q167 240 191 225 L189 201 M204 180 Q249 211 221 224 L197 204', '#999ee9') + path('M99 85 L104 61 L123 71 L139 51 L152 79Z', '#9bd39f'),
    path('M90 88 L84 65 C44 43 79 12 102 37 C114 8 147 12 154 37 C180 15 206 52 176 65 L169 89Z', '#fff5db') + path('M44 149 L16 115 L12 148 L32 173 M212 149 L240 115 L244 148 L224 173', '#f19884'),
    path('M114 88 L132 32 L162 88Z', '#aac4f1') + '<ellipse cx="128" cy="55" rx="59" ry="16" fill="none" stroke="#ffe5a7" stroke-width="7"/>' + path('M34 140 L17 174 L47 187 M218 140 L239 174 L209 187', '#d5e7ff'),
    rect(102, 51, 54, 37, '#a294e4') + path('M176 156 L218 94 L234 108 L190 170Z', '#c4b8ff') + path('M72 95 L77 81 L82 95 L96 100 L82 105 L77 119 L72 105 L58 100Z', '#fff1bc', 3),
    path('M89 89 L52 46 L74 40 L129 77 L179 40 L204 47 L166 91Z', '#abd578') + ellipse(128, 96, 22, 22, '#f4df75', '#223347') + path('M126 78 L118 93 L125 93 L120 111 L138 88 L130 88 L135 78Z', '#596b54', 2),
    '<ellipse cx="128" cy="143" rx="116" ry="34" fill="none" stroke="#dbabff" stroke-width="12" transform="rotate(-27 128 143)"/>' + path('M128 39 L140 67 L171 68 L148 89 L154 119 L128 103 L102 119 L108 89 L85 68 L116 67Z', '#d9b5ff', 5),
]
roster = re.findall(r'\["([a-z_]+)",', (ROOT / 'scripts/data/SlimerotRoster.gd').read_text(encoding='utf-8'))
palette = ['#bd996f', '#9ecb94', '#ebcd75', '#eab2cf', '#b8b3d5', '#81cbd6', '#b7cfa3', '#b7dce1', '#8cbeaa', '#eca89b', '#c7dae8', '#d5bce5', '#e6bd77', '#d6b3a0', '#c9bfdd', '#8bb998', '#c7cc8b', '#b3bccd', '#a49ee4', '#efaa94', '#a7c8ec', '#b19bdf', '#b8cf82', '#aa8be0']
for i, slime_id in enumerate(roster):
    svg('slimes', slime_id, blob(palette[i], '#ffffff', i, i) + props[i])

svg('player', 'player', path('M94 64 L106 39 L139 28 L165 57 L166 86Z', '#79ce9d') + blob('#a7e8bb', '#e6ffe0') + rect(90, 183, 76, 31, '#6eb8db') + path('M88 199 L102 171 H153 L169 199', '#ffe9a6', 5))

enemy_colors = ['#e49bb5', '#e9b684', '#b5c88e', '#e7c287', '#db9ece', '#c6d588', '#b7c6ed', '#c39bea']
theme_props = [path('M112 87 L87 58 L127 67 L157 42 L151 87Z', '#a6d68e'), path('M82 92 Q78 59 128 59 Q177 60 174 92Z', '#b46364'), path('M73 105 L63 66 L84 86 M173 92 L192 65 L187 111', '#9bab7a'), path('M81 94 Q68 62 100 63 H167 L177 94Z', '#efdfb5'), rect(86, 74, 81, 20, '#91dce1', 5), path('M79 96 Q128 57 178 96 L161 109 L128 93 L95 110Z', '#e3d390'), '<ellipse cx="128" cy="121" rx="99" ry="70" fill="none" stroke="#dee9f3" stroke-width="7"/>', path('M128 41 L152 77 L128 101 L104 77Z', '#e6b8fa')]
for zone in range(1, 9):
    for a, archetype in enumerate(['chaser', 'shooter', 'tank']):
        body = blob(enemy_colors[zone - 1], '#ffffff', 2, a)
        if archetype == 'chaser':
            body += path('M46 189 L32 213 L74 211 M208 189 L223 213 L182 211', '#f9e8c6')
        elif archetype == 'shooter':
            body += path('M103 167 L119 202 L141 202 L155 167Z', '#8b91ad') + ellipse(130, 185, 10, 10, '#273c4c')
        else:
            body += path('M62 149 L90 175 L128 161 L169 175 L196 149 L193 199 L128 224 L65 199Z', '#72869a') + ellipse(129, 194, 12, 12, '#e3d09c', '#223347')
        svg('enemies', f'z{zone}_{archetype}', body + theme_props[zone - 1])

boss_props = [rect(68, 49, 125, 59, '#ebe0cf') + path('M195 53 C249 41 250 108 195 101', 'none', 13) + path('M63 178 L89 162 L106 195 L78 213 M195 178 L170 162 L154 195 L182 213', '#b28c71'), rect(63, 62, 133, 49, '#e7d49e') + path('M80 66 L60 22 M178 66 L198 22', 'none', 12) + ellipse(90, 91, 6, 6, '#92cc91') + ellipse(114, 91, 6, 6, '#92cc91'), path('M53 87 L76 49 H180 L202 87 L167 105 H89Z', '#c9b774') + path('M199 192 L226 79 M204 69 H246 L243 94 H202Z', '#a5c2bf') + rect(96, 186, 65, 24, '#788985'), path('M61 100 L53 37 L94 60 L128 23 L163 60 L204 37 L195 100Z', '#cfadf4') + rect(60, 125, 139, 31, '#625984') + path('M109 180 L96 191 L109 202 M147 180 L160 191 L147 202', 'none', 6, '#f0d6ff')]
for i, boss_id in enumerate(['espresso_golem', 'sand_router', 'backrooms_janitor', 'singularity_admin']):
    svg('bosses', boss_id, blob(['#b8a08a', '#dbc087', '#b3bd86', '#b795df'][i], '#ffffff', 2, i) + boss_props[i], 512)

ground = ['#5e9473', '#bc9071', '#477570', '#d5b377', '#586c91', '#a89c66', '#8693b8', '#765493']
for i, name in enumerate(['backyard', 'italian_village', 'cursed_forest', 'sahara', 'brainrot_city', 'backrooms', 'moon', 'brainrot_dimension']):
    tile = f'<rect width="256" height="256" fill="{ground[i]}" stroke="none"/>'
    if i in (1, 4, 5):
        tile += '<path d="M0 64 H256 M0 128 H256 M0 192 H256 M64 0 V64 M192 0 V64 M128 64 V128 M64 128 V192 M192 128 V192 M128 192 V256" fill="none" stroke="#ffffff" stroke-opacity="0.11" stroke-width="3"/>'
    elif i == 3:
        tile += '<path d="M-20 58 Q44 20 108 58 T276 58 M-10 173 Q54 140 118 173 T280 173" fill="none" stroke="#ffedbf" stroke-opacity="0.27" stroke-width="5"/>'
    elif i == 6:
        for x, y, r in [(56, 51, 22), (190, 186, 33), (135, 110, 12)]:
            tile += f'<circle cx="{x}" cy="{y}" r="{r}" fill="#64799d" stroke="#b1c2d7" stroke-opacity="0.32" stroke-width="3"/>'
    elif i == 7:
        tile += path('M48 62 L56 79 L74 84 L56 89 L48 106 L40 89 L22 84 L40 79Z M191 163 L200 186 L222 193 L200 200 L191 222 L182 200 L160 193 L182 186Z', '#a283bc', 0)
    else:
        tile += '<path d="M38 71 L33 56 M38 71 L44 59 M182 207 L176 190 M182 207 L191 195 M148 44 L142 31" fill="none" stroke="#a8cdaa" stroke-opacity="0.48" stroke-width="4"/>'
    svg('zones', name, tile)

base = rect(45, 185, 168, 38, '#78929f') + rect(59, 166, 142, 29, '#a2b7bf')
structures = {
    'skill_tree_shrine': base + rect(95, 82, 68, 94, '#b5c8bd') + path('M128 31 L177 82 L128 133 L79 82Z', '#bbef96') + path('M128 55 V107 M111 71 L128 87 L148 69', 'none', 6, '#4e805d'),
    'sell_terminal': base + rect(65, 45, 126, 116, '#93b6c6') + rect(80, 62, 96, 65, '#315769') + ellipse(129, 94, 22, 24, '#f5d580', '#e8ba66') + path('M120 95 H138 M130 82 V107', 'none', 5, '#997543') + rect(85, 140, 83, 9, '#dcf1e5', 3),
    'potion_bench': base + rect(30, 143, 196, 28, '#b89478') + path('M76 83 V50 H104 V84 Q140 132 93 141 Q41 130 76 83Z', '#91d9ba') + path('M153 99 V66 H180 V99 Q213 137 168 142 Q124 136 153 99Z', '#d4a5e6') + path('M69 109 H113 M143 118 H193', 'none', 5, '#e9fff0'),
    'fast_travel_pillar': base + path('M78 176 L87 78 L128 33 L170 78 L179 176Z', '#b9c6d6') + path('M133 64 L99 110 H125 L113 151 L155 99 H131Z', '#a7efd3', 4),
    'mutation_lab': base + rect(51, 46, 153, 132, '#969dbb') + rect(72, 62, 112, 94, '#d2e1e5') + path('M106 77 C169 95 91 116 151 141 M151 77 C87 95 167 116 106 141', 'none', 8, '#9a7cc4') + path('M115 86 H142 M111 105 H146 M114 131 H143', 'none', 5, '#77b59a'),
    'gate_closed': base + path('M51 185 V71 Q128 0 205 71 V185 H177 V80 Q129 38 79 80 V185Z', '#aab9a2') + rect(82, 102, 91, 62, '#d2b579') + path('M97 103 V86 Q128 47 158 86 V104', 'none', 12),
    'gate_open': base + path('M51 185 V71 Q128 0 205 71 V185 H177 V80 Q129 38 79 80 V185Z', '#b0dba8') + path('M128 93 V158 M105 134 L128 159 L152 134', 'none', 12, '#edffc8'),
    'portal': base + '<ellipse cx="128" cy="115" rx="67" ry="86" fill="#7c62a6" stroke="#d5b7ff" stroke-width="15"/>' + '<ellipse cx="128" cy="115" rx="37" ry="58" fill="#ac8bd5" stroke="#e6d8ff" stroke-width="6"/>' + path('M128 82 L138 105 L158 114 L138 122 L128 146 L119 122 L99 114 L119 105Z', '#f5eaff', 0),
    'boss_portal': base + '<ellipse cx="128" cy="115" rx="67" ry="86" fill="#745575" stroke="#eba0b9" stroke-width="15"/>' + path('M89 90 L83 65 L111 80 L128 58 L147 80 L174 65 L166 110 H91Z', '#f3c584') + ellipse(108, 138, 9, 12, '#f9d9df') + ellipse(150, 138, 9, 12, '#f9d9df'),
}
for name, body in structures.items():
    svg('structures', name, body)

icons = {
    'coins': ellipse(128, 128, 92, 92, '#f3d273', '#805f37') + ellipse(128, 128, 66, 66, '#ffe6a0', '#d3ab53') + path('M139 82 H111 V123 H146 V168 H110 M128 68 V187', 'none', 11, '#997742'),
    'rolls': rect(45, 44, 168, 168, '#c3a6f0', 37) + ''.join(ellipse(x, y, 13, 13, '#fff4db') for x, y in [(87, 88), (170, 88), (129, 128), (87, 170), (170, 170)]),
    'luck': path('M126 127 C53 161 26 104 63 76 C25 32 104 6 126 76 C149 9 231 32 189 78 C235 113 199 164 132 133 Q130 186 161 209', '#a8df8e', 9),
    'hp': path('M128 215 C97 184 29 139 30 85 C31 31 100 29 128 71 C159 24 227 38 228 89 C228 141 158 190 128 215Z', '#f1a5b8') + path('M80 70 Q55 77 58 102', 'none', 10, '#ffe4eb'),
    'auto': path('M42 107 A88 88 0 0 1 206 88 L227 69 L224 131 L164 111 L183 98 A58 58 0 0 0 71 113Z M214 152 A88 88 0 0 1 49 171 L28 190 L33 130 L90 149 L73 162 A58 58 0 0 0 184 145Z', '#aadbb7', 5),
    'team': blob('#a9d9b6', '#e6ffdf') + ellipse(48, 170, 28, 33, '#c6b0e9', '#223347') + ellipse(207, 170, 28, 33, '#f4cb84', '#223347'),
    'inventory': rect(39, 65, 179, 154, '#a9c9d8', 25) + path('M91 64 V43 H167 V65 M40 106 H216', 'none', 11) + rect(109, 91, 43, 45, '#f4d78a'),
    'collection': path('M29 53 Q80 26 128 54 Q178 26 228 54 V206 Q176 181 128 206 Q79 181 29 207Z', '#d0b7e9') + path('M128 58 V202 M52 91 H103 M153 91 H204 M54 121 H101 M155 121 H202 M52 151 H103', 'none', 8, '#f8f0ff'),
    'skills': path('M128 76 V181 M66 129 H190 M65 129 V181 M191 129 V181', 'none', 15, '#87ba9a') + ellipse(128, 56, 31, 31, '#f2d787', '#223347') + ellipse(64, 193, 27, 27, '#a4dbad', '#223347') + ellipse(128, 193, 27, 27, '#c1ade8', '#223347') + ellipse(193, 193, 27, 27, '#a4cbdc', '#223347'),
    'settings': path('M107 24 H149 L157 53 L181 63 L208 52 L230 88 L208 110 V139 L230 165 L208 203 L179 191 L155 204 L149 232 H107 L100 204 L75 191 L47 203 L25 166 L47 140 V112 L25 88 L47 51 L75 64 L100 51Z', '#b9c4db') + ellipse(128, 128, 44, 44, '#f1eaf7', '#223347'),
}
for name, body in icons.items():
    svg('ui', name, body)

SAMPLE_RATE = 22050


def tone(samples, start, duration, frequency, gain=0.1, slide=0.0):
    begin = round(start * SAMPLE_RATE)
    count = round(duration * SAMPLE_RATE)
    for i in range(count):
        if begin + i >= len(samples):
            break
        t = i / SAMPLE_RATE
        envelope = min(1.0, t / 0.008) * min(1.0, (duration - t) / 0.04)
        phase = 2 * math.pi * (frequency * t + slide * t * t / 2)
        samples[begin + i] += gain * envelope * (math.sin(phase) + 0.2 * math.sin(phase * 2))


def wav(name, samples):
    AUDIO.mkdir(parents=True, exist_ok=True)
    with wave.open(str(AUDIO / f'Slimerot_{name}.wav'), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(b''.join(struct.pack('<h', round(max(-0.95, min(0.95, value)) * 32767)) for value in samples))


for name, beat, sequence, bassline in [
    ('exploration', 0.4, [72, 76, 79, 74, 76, 81, 79, 76, 72, 76, 79, 83, 81, 79, 76, 74, 69, 72, 76, 79, 76, 74, 72, 76, 67, 71, 74, 79, 76, 74, 71, 74], [48, 53, 45, 43]),
    ('boss', 0.3, [60, 67, 63, 70, 60, 67, 63, 72, 56, 63, 60, 67, 56, 63, 60, 70, 58, 65, 62, 69, 58, 65, 62, 70, 55, 62, 59, 65, 55, 62, 59, 67], [36, 32, 34, 31]),
]:
    samples = [0.0] * round(32 * beat * SAMPLE_RATE)
    for i, note in enumerate(sequence):
        tone(samples, i * beat, beat * 0.75, 440 * 2 ** ((note - 69) / 12), 0.10)
        if i % 2 == 0:
            tone(samples, i * beat, beat * 1.6, 440 * 2 ** ((bassline[i // 8] - 69) / 12), 0.13)
        tone(samples, i * beat, 0.08, 95 if i % 2 == 0 else 220, 0.045, -500)
    wav(name, samples)

cues = {
    'roll': (0.10, [(0, 0.07, 620, 0.24, -3500)]),
    'rare': (0.65, [(0, 0.22, 523, 0.18, 0), (0.13, 0.23, 659, 0.18, 0), (0.27, 0.33, 784, 0.20, 0)]),
    'jackpot': (1.65, [(0, 0.32, 523, 0.16, 0), (0.17, 0.32, 659, 0.16, 0), (0.34, 0.33, 784, 0.16, 0), (0.55, 1.0, 1046, 0.15, 0), (0.55, 1.0, 659, 0.10, 0), (0.55, 1.0, 784, 0.10, 0)]),
    'hit': (0.10, [(0, 0.09, 230, 0.23, -1300)]),
    'enemy_death': (0.19, [(0, 0.17, 480, 0.20, -1800)]),
    'purchase': (0.24, [(0, 0.11, 698, 0.18, 0), (0.10, 0.13, 1046, 0.18, 0)]),
    'gate': (0.65, [(0, 0.22, 330, 0.15, 0), (0.15, 0.22, 440, 0.15, 0), (0.3, 0.30, 659, 0.20, 0)]),
    'breakthrough': (0.90, [(0, 0.23, 330, 0.18, 440), (0.18, 0.23, 523, 0.18, 440), (0.37, 0.45, 1046, 0.17, 0), (0.37, 0.45, 659, 0.12, 0), (0.37, 0.45, 784, 0.10, 0)]),
}
for name, (duration, notes) in cues.items():
    samples = [0.0] * round(duration * SAMPLE_RATE)
    for note in notes:
        tone(samples, *note)
    wav(name, samples)

print(f'Slimerot placeholders: {len(list(ART.rglob("*.svg")))} SVGs, {len(list(AUDIO.glob("*.wav")))} WAVs.')
