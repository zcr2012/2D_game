# AI 生图提示词

所有原图都放在 `art_src/raw/<名字>.png`，然后运行
`python3 tools/process_assets.py <名字>`，脚本会自动抠绿幕、裁切、缩放、减色。

## 通用规则（换别的生图工具也照这个来）

1. **背景必须是纯绿 `#00FF00`**，不要地面、不要投影、不要文字和边框（脚本靠绿色抠图）。
2. **视角统一**：三分之四俯视（相机大约在上方 35°），和游戏里的其他道具一致。
3. **风格统一**：“Blender 渲染的黏土 / 玩具质感 3D”，柔和棚拍光，**光从左上方来**。
4. 物体居中、完整、四周留白；原图尺寸随意（这两张是 1254×1254 和 1086×1448），脚本会统一大小。
5. 物体本身**不要用绿色**，否则会被抠掉（薄荷绿、浅绿一般没问题，纯绿不行）。

---

## 旋转木马 `carousel`（城镇东南角的地标道具）

处理结果：高 130 px，64 色（`ASSETS["carousel"]`）。

```
A whimsical candy carousel (merry-go-round) made entirely of sweets, as a single game prop.
Striped red-and-white peppermint candy-cane poles, a scalloped pink strawberry-frosting canopy
roof trimmed with colorful gumdrops and a big cherry on top, three gingerbread horses with white
icing details, a round glossy caramel-and-biscuit base platform with sprinkles.
Three-quarter top-down view (about 35 degrees from above), stylized 3D render in the style of a
Blender cycles clay/toy render, soft rounded shapes, smooth subsurface candy materials, pastel
pink, mint, cream and caramel palette, soft studio lighting from the upper left.
The entire object fully visible and centered with generous margin. Isolated on a perfectly flat
pure chroma-key green #00FF00 background, no ground, no cast shadow on the background, no text,
no border.
```

中文意思：一座完全用糖果做的旋转木马——红白薄荷拐杖糖柱子、粉色草莓糖霜波浪顶棚（点缀软糖，顶上一颗樱桃）、三匹带白色糖霜花纹的姜饼马、焦糖饼干圆底座撒满彩色糖粒；三分之四俯视，Blender 黏土玩具风 3D 渲染，粉 / 薄荷绿 / 奶油 / 焦糖配色，左上方柔光；纯绿背景，无地面无投影无文字。

## 巧克力墙 `chocowall`（迷宫墙砖，要能无缝拼接）

处理结果：**精确 48×64 px 的不透明砖块**，32 色（`TILES["chocowall"]`，走“贴图模式”：拉伸到固定尺寸、边缘补成不透明，左右上下相邻时不会有缝）。

```
A single cube-shaped block of dark milk chocolate, used as a tileable maze wall block in a 2D
top-down game. Three-quarter top-down view (camera about 35 degrees above, looking straight on,
no perspective rotation): the top face is visible as a lighter glossy chocolate surface, the
front face shows a chocolate-bar pattern of four embossed rounded squares, a few small drips of
melted chocolate hang from the top front edge, tiny white sugar sprinkles on top.
The block is perfectly symmetrical and rectangular with straight vertical sides so it can be
placed side by side seamlessly; its outline is about 3 units wide by 4 units tall (top face
occupies the upper quarter). Stylized 3D render in the style of a Blender cycles clay/toy
render, smooth rich materials, warm brown palette, soft studio lighting from the upper left.
Centered with margin, isolated on a perfectly flat pure chroma-key green #00FF00 background,
no ground, no cast shadow, no text.
```

中文意思：一块方方正正的牛奶巧克力砖，用作俯视角 2D 游戏里可拼接的迷宫墙；正对镜头的三分之四俯视（**不要旋转透视**）；顶面是更亮的光滑巧克力、撒白色糖粒，正面是四格巧克力排块浮雕，顶部前沿挂着几滴融化的巧克力；**左右对称、侧边笔直、宽高约 3:4、顶面占上四分之一**（这样才能和 48×64 的格子对上）；Blender 黏土风，暖棕色，左上方柔光；纯绿背景。

**要点**：墙砖的提示词里“正对、不旋转、侧边笔直、3:4 比例”这几条最关键——一旦生成成斜 45° 的立方体，就拼不成迷宫了。

---

## 梦境二《梧桐巷》素材清单

AI 生成（绿幕原图在 `art_src/raw/`，由 `tools/process_assets.py` 处理）：

| 名字 | 用途 | 风格要点 |
|---|---|---|
| `shenyuan` | 沈远，82 岁退休修理工 | 像素角色，驼背，旧夹克，工装裤 |
| `laodeng` | 老灯（梦之人格，会数人的路灯） | 老式铸铁路灯 + 一点人的神态，暖黄灯罩 |
| `fubo` | 福伯，面馆老板 | 像素角色，围裙 |
| `suwan` | 苏晚（缺失的人） | 像素角色，撑伞，浅色外套 |
| `faceless` | 没有脸的路人 / 被遗忘的人 | 像素角色，脸是一块光滑的空白 |
| `st_noodle` `st_repair` `st_studio` `st_flat` `st_tree` | 面馆、修理铺、照相馆、居民楼、梧桐树 | “3D 渲染小场景”风格的道具，绿幕背景 |

另外 5 个道具也是 AI 生成（同一套绿幕流程）：`st_bench`（长椅 + 车站牌 + 被遗忘的伞）、`st_lamp`（老式铸铁路灯）、`st_shutter`（生锈的卷帘门）、`st_signpost`（路牌，空白牌面，文字由游戏里的 Label 画）、`st_planter`（花盆）。`procedural_assets.py` 里同名的程序化版本只在 `art_src/raw/` 没有原图时才会生成。

程序化生成（`tools/procedural_assets.py street`）：街道地面三种形态（`street_ground_*`）、积水、窗户、光桥、回声之雾，以及三首循环音乐（`street_summer / street_fading / street_echo`，电钢琴音色）。以后可以用同名 AI 图替换。
