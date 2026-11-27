# Zom Nom Defense - Visual Style Guide

**Last Updated**: October 25, 2025  
**Status**: Draft - To be refined during Phase 6 visual polish pass

---

## Visual Direction

### Core Aesthetic: Modern Lo-Fi

**Definition**: Stylized, low-polygon 3D art with simple textures that emphasize readability, charm, and efficiency over realism.

**NOT**: Retro/blocky Minecraft-style, PS1-era jaggy polygons, or pixel art aesthetic  
**YES**: Modern indie game style - smooth organic forms with reduced detail (Firewatch, A Short Hike, Sable)

### Key Principles

1. **Readable** - Easy to identify enemies, towers, and game elements at a glance
2. **Charming** - Inviting and comedic, not scary or gross
3. **Efficient** - Quick to create assets, good performance
4. **Cohesive** - Consistent style across all elements
5. **Timeless** - Won't look dated in 5 years

---

## Technical Specifications

### Polygon Counts

| Asset Type | Target Poly Count | Notes |
|------------|-------------------|-------|
| **Characters** (zombies, survivors) | 500-2000 | Focus on silhouette clarity |
| **Small props** (weapons, items) | 100-500 | Simple recognizable shapes |
| **Medium props** (campfire, trees) | 200-1000 | Organic but simplified |
| **Large props** (pool, structures) | 500-2000 | Balance detail vs performance |
| **Terrain tiles** | 50-200 | Kept very simple for performance |

### Textures

- **Resolution**: 512x512 to 1024x1024 maximum
- **Style**: Hand-painted, gradient, or solid colors
- **Detail Level**: Simple, no fine details like individual stitches or scratches
- **Maps**: Diffuse + optional AO, minimal normal maps
- **Format**: PNG for transparency needs, otherwise compressed formats

### Materials & Shaders

- Simple shaders (toon, cel-shaded, or custom painterly)
- Flat or simple gradient lighting
- Soft shadows
- No PBR materials (no metallic/roughness complexity)
- Consistent rim lighting for readability

---

## Color Palette

### Zombie Color Families

- **Standard Zombies**: Desaturated greens (#7A9B76, #5F7A5A)
- **Fast Zombies**: Warm reds/oranges (#C95D4F, #E8856F)
- **Tank Zombies**: Cool grays (#6B7280, #9CA3AF)
- **Special Zombies**: Purples/yellows for unique types

### Environment Colors

- **Terrain Base**: Earthy browns (#8B7355, #A68A6E)
- **Grass**: Vibrant but not saturated greens (#88B04B, #6B8E3B)
- **Water**: Stylized blues (#5DA5DA, #4A8DB8)
- **Props**: Bright accent colors for visual interest

### UI Colors

- **Primary Actions**: Bright green (#4CAF50)
- **Warnings**: Orange/yellow (#FF9800)
- **Danger**: Red (#F44336)
- **Info**: Blue (#2196F3)
- **Background**: Dark neutral (#2C3E50)

### Guidelines

- Use limited palette for cohesion
- High contrast between gameplay elements
- Avoid pure black and pure white
- Test colorblind accessibility

---

## Character Design

### Zombies

**Style**: 
- Humanoid, slightly hunched posture
- Smooth low-poly forms (not blocky)
- Proportions can be slightly exaggerated for comedy

**Proportions**:
- Normal to slightly-larger heads for expressiveness
- Limbs can be slightly elongated for shambling effect
- Distinct silhouettes for each type

**Features**:
- Clear zombie characteristics (posture, color, movement) without gore
- Simple facial features (sunken eyes, slack jaw)
- Torn clothing suggested by texture, not geometry

**Animation Notes**:
- Shambling, lurching movement
- Simple but distinctive walk cycles per type
- Death animations: simple ragdoll or fade out

### Survivors

**Style**:
- More upright, alert posture
- Normal proportions for contrast with zombies
- Expressive and animated

**Clothing**:
- Simple, recognizable (solid color shirts/pants)
- 2-3 color outfit maximum
- Minimal geometric detail

**Animations**:
- Reactive and comedic (wobble, jump, panic)
- Idle animations showing personality
- Looking toward nearest zombie

---

## Environment Design

### Props

**Natural Elements**:
- Trees: Trunk + foliage clumps (not individual leaves)
- Rocks: Smooth, rounded forms
- Water: Simple plane with animated shader

**Man-Made Elements**:
- Campfire: Simple logs + flame geometry + particles
- Pool: Blue plane + white edge rim
- Boxes/Crates: Rounded cube forms

**Design Principles**:
- **Recognizable at a glance** - clear what each prop is
- **Simplified geometry** - reduce polys while keeping shape
- **Painterly textures** over photorealism
- **Support comedic absurdity** (oversized pool floaties, etc.)

### Terrain

- Painted/stylized ground textures (not photo-based)
- Simple height variations (hills, valleys)
- Grid faintly visible for placement clarity
- Clear walkable vs non-walkable areas
- Minimal texture tiling artifacts

---

## UI Style

### Visual Language

- Clean, modern interface
- Consistent with 3D art style
- Simple geometric shapes (rounded rectangles, circles)
- Flat or subtle gradients
- Clear visual hierarchy

### Typography

- Clean sans-serif font
- High contrast with background
- Large enough for readability
- Consistent sizing system

### Icons

- Simple, clear silhouettes
- Match art style (not photorealistic)
- Consistent stroke weight
- Recognizable at small sizes

### Feedback

- Simple particle effects
- Screen shake for impact
- Color flashes for state changes
- Sound + visual confirmation for actions

---

## Effects & Particles

### Visual Effects

**Particle Systems**:
- Simple geometric shapes (spheres, cubes, planes)
- Short lifetimes (0.5-2 seconds)
- Clear purpose (muzzle flash, impact, death)

**Examples**:
- **Turret Fire**: Small yellow spheres + brief flash
- **Zombie Death**: Green puff particles + fade out
- **Impact**: White flash + small debris
- **Scrap Pickup**: Coins floating up with trail

**Guidelines**:
- Understated, not overwhelming
- Match color palette
- Don't obscure gameplay
- Performance-friendly (low particle counts)

---

## Reference Games

### Primary Inspiration

1. **Firewatch** - Painterly textures, stylized nature
2. **A Short Hike** - Charming low-poly, inviting atmosphere
3. **Sable** - Comic book aesthetic, clean lines
4. **Dorfromantik** - Toy-like, clean, satisfying to look at
5. **Kentucky Route Zero** - Simple geometry, atmospheric

### What We're NOT Going For

❌ **Minecraft** - Too blocky/cubic  
❌ **SUPERHOT** - Too abstract/minimal  
❌ **Obra Dinn** - Too retro/1-bit  
❌ **Realistic/AAA** - Too detailed/complex  
❌ **Pixel Art** - Different medium entirely

---

## Implementation Workflow

### Modeling Process

1. **Concept/Sketch** - Define basic shapes and proportions
2. **Block Out** in Blender with primitives
3. **Refine** with subdivision surfaces (level 1-2 max)
4. **Optimize** topology for smooth curves with low poly count
5. **UV Unwrap** with simple, efficient layouts
6. **Export** with proper normals and scaling

### Texturing Process

1. **UV Layout** - Keep it simple and organized
2. **Base Colors** - Block in main color areas
3. **Add Detail** - Subtle shading, edge highlights
4. **AO Pass** (optional) - Bake from high-poly if needed
5. **Test** in-game at camera distance
6. **Iterate** based on readability

### Shader Setup (Godot)

```gdscript
# Example toon shader setup
shader_type spatial;
render_mode unshaded; // or use simple shading

uniform sampler2D texture_albedo : hint_albedo;
uniform vec4 albedo_tint : hint_color = vec4(1.0);
uniform float rim_amount : hint_range(0.0, 1.0) = 0.5;
uniform vec4 rim_color : hint_color = vec4(1.0);

// Simple toon shading with rim light
void fragment() {
    vec4 tex = texture(texture_albedo, UV);
    ALBEDO = tex.rgb * albedo_tint.rgb;
}

void light() {
    // Simplified toon lighting
    float NdotL = dot(NORMAL, LIGHT);
    float toon = step(0.5, NdotL);
    DIFFUSE_LIGHT += ALBEDO * toon * ATTENUATION;
}
```

### Testing Checklist

- [ ] Looks good at gameplay camera distance
- [ ] Silhouette is clear and recognizable
- [ ] Performance is acceptable (check poly count, draw calls)
- [ ] Matches established style guide
- [ ] Colorblind accessible (if gameplay-critical)
- [ ] Works in different lighting conditions
- [ ] Animations read clearly

---

## Asset Organization

### Directory Structure

```
Assets/
├── Models/
│   ├── Characters/
│   │   ├── Zombies/
│   │   │   ├── zombie_basic.blend
│   │   │   ├── zombie_fast.blend
│   │   │   └── zombie_tank.blend
│   │   └── Survivors/
│   │       ├── survivor_01.blend
│   │       └── survivor_02.blend
│   ├── Props/
│   │   ├── campfire.blend
│   │   ├── tree.blend
│   │   └── pool.blend
│   └── Environment/
│       ├── terrain_tile.blend
│       └── obstacles.blend
├── Textures/
│   ├── Characters/
│   ├── Props/
│   └── Environment/
└── Materials/
    ├── character_toon.material
    ├── prop_simple.material
    └── terrain.material
```

### Naming Conventions

- **Models**: `category_name_variant.blend`
- **Textures**: `model_name_diffuse.png`, `model_name_ao.png`
- **Materials**: `category_shader.material`

---

## Iteration & Feedback

### Prototype First

- Start with placeholder geometry
- Test in gameplay context
- Get feedback early
- Refine based on actual needs

### Review Process

1. Create asset following style guide
2. Test in game at proper camera angle
3. Check against style references
4. Get team feedback (if applicable)
5. Iterate if needed
6. Document any style guide updates

### Common Pitfalls to Avoid

❌ Too much detail - remember, simple is better  
❌ Inconsistent poly counts - keep similar assets similar  
❌ Texture resolution too high - wastes memory  
❌ Over-complicated UV layouts - keep it simple  
❌ Forgetting to test at game camera distance  
❌ Making assets that don't read clearly in gameplay

---

## Future Considerations

### Post-Launch Content

If creating new content after initial release:
- Maintain consistency with established style
- Reference this guide for all new assets
- Update guide if style evolves
- Keep performance in mind

### Potential Style Variations

- Different biomes (desert, snow) could have shifted palettes
- Special events could have themed variants
- Boss characters could be slightly more detailed for emphasis

---

## Questions & Decisions Log

### Open Questions

- Final decision on exact color palette values?
- Specific shader implementation (toon vs custom)?
- Level of cartoon outline (if any)?
- Particle effect complexity level?

### Resolved Decisions

- ✅ Modern lo-fi over retro blocky style
- ✅ Smooth organic forms, not cubic
- ✅ Poly count ranges established
- ✅ Reference games identified

---

*This is a living document. Update as style evolves during development.*

**Related Documents**:
- `docs/zom_nom_defense_gdd.md` - Overall game vision

---

## Color Palette

Extracted from the game logo and used throughout the UI theme. Implemented in the UI theme resources: `Config/ztd_ui_theme.tres` and `Config/ztd_hud_theme.tres`. The broader `Config/ztd_color_palette.tres` may define additional colors for environments and other uses beyond this UI set.

### Primary Colors

| Name | Hex | Godot | Usage |
|---|---|---|---|
| **Orange** (Primary Accent) | `#F2A75A` | `Color(0.949, 0.655, 0.353, 1)` | Title text, button hover, panel borders, focus states |
| **Cream/Beige** (Text) | `#EBD9BC` | `Color(0.922, 0.851, 0.737, 1)` | Primary text, button text, labels, hover borders |
| **Dark Teal** (Background) | `#2C4A4E` | `Color(0.172, 0.29, 0.306, 1)` | Panel backgrounds, disabled button backgrounds |
| **Zombie Green** (Buttons) | `#6B8C5E` | `Color(0.42, 0.549, 0.369, 1)` | Normal button background, interactive elements |
| **Darker Green** (Pressed) | `#5A7A4D` | `Color(0.353, 0.478, 0.302, 1)` | Button pressed state background |
| **Dark Navy** (Outlines) | `#1A1F2E` | `Color(0.102, 0.122, 0.18, 1)` | Button borders, text shadows, outlines |

### Color Usage by UI Element

**Buttons**
- Normal: Zombie Green bg, Dark Navy border, Cream text
- Hover: Orange bg, Cream border, Cream text
- Pressed: Darker Green bg, Orange border, Orange text
- Disabled: Dark Teal bg (50% opacity), Dark Navy border (50%), Cream text (50%)

**Panels**: Dark Teal bg (90% opacity), Orange border

**Text**: Cream/Beige primary · Dark Navy shadow (80%) · Orange for focus/accent

### Design Notes

Inspired by the game logo: bold orange lettering, zombie green undead elements, dark teal post-apocalyptic atmosphere, cream text for readability.
