---
description: "Pinned dark house style for HVE demo-material decks, covering the palette and its colour roles, typography, shape conventions, and the contrast expectation."
---

# Demo Material House Style

## Why the Style Is Pinned

Three runs produced three different looks. L100 and L200 built a dark deck from
seven colours on a `#1B1B1F` background with Microsoft blue and cyan accents. A
later L300 built a light deck instead: sixteen colours, an off-white background,
black text, a white card fill, and teal, green, orange, and yellow accents.
Nothing in this skill described a style, so nothing detected the drift, and an
unattended `full` run would not have caught it either.

A level's deck is one item in a set. L100 and L400 reach different audiences,
but they are watched as the same product, so they have to look like the same
product. The palette below is fixed rather than advisory, and
`templates/style.yaml` is the copy source every run starts from.

The pinned look is the L100 and L200 dark deck, kept as produced rather than
redesigned. Two refinements were applied when it was pinned, and both are
recorded under Shape Conventions.

## Palette

These are the only colours a deck uses. Each carries one role.

| Style field                                         | Value     | Role                                                                |
|-----------------------------------------------------|-----------|---------------------------------------------------------------------|
| `themes[0].colors.bg_dark`                          | `#1B1B1F` | Page background on every slide                                      |
| `themes[0].colors.bg_card` and `defaults.card.fill` | `#2D2D35` | Card and panel fill                                                 |
| `defaults.card.border_color`                        | `#3D3D45` | Card outline, drawn at 1 pt                                         |
| `themes[0].colors.text_primary`                     | `#F8F8FC` | Titles, headings, and body text                                     |
| `themes[0].colors.text_secondary`                   | `#C9CDD6` | Supporting text, captions, and source citations                     |
| `defaults.title_bar.color`                          | `#0078D4` | Structural accent, used for the title bar across the top of a slide |
| `defaults.accent_bar.color`                         | `#00B4D8` | Emphasis accent, used for the thin bar that marks a heading or card |

`#0078D4` and `#00B4D8` are the only accent colours in the house style. A slide
picks one of the two for its emphasis. Do not mix both on one slide, and do not
add a third hue to carry a distinction that ordering, position, or a card
boundary already carries.

## Shape Conventions

* Title bar: `height_inches: 0.12` at `top_inches: 0`, so it sits flush with the
  top edge of the slide.
* Accent bar: `height_inches: 0.04`, thinner than the title bar so the two read
  as a hierarchy rather than as two rules of equal weight.
* Card: `fill: "#2D2D35"` with a 1 pt `#3D3D45` border.
* Card rounding: `corner_radius_inches: 0.06`. This is the first of the two
  refinements applied when the style was pinned. The L100 and L200 decks used
  0.15, and the flatter 0.06 keeps a card reading as a panel rather than as a
  button.
* One accent per slide. This is the second refinement. The produced decks let
  several accent colours compete inside a single slide, which spent emphasis
  without directing it.

## Typography

Segoe UI is the only typeface. Sizes are set per element in each slide's
`content.yaml` rather than in `style.yaml`, so they are a convention that the
style file does not enforce. The produced decks use roughly 54 pt for the
opening deck title, 34 pt for a slide title, 28 pt and 20 pt for subheads, and
16 to 18 pt for body and card text.

## Contrast Expectation

Supporting text has to stay legible against the dark background. `#C9CDD6` is
the pinned value for that role, over both `#1B1B1F` and `#2D2D35`. L100 used
`#9CA3AF` for the same role and drew low-contrast findings from the vision
slide check, so `#C9CDD6` replaces it everywhere. That vision check, which gates
`validation.deck: pass`, is where a contrast regression surfaces.

## What a Run Substitutes

Copy `templates/style.yaml` to the level's `content/global/style.yaml` and
change only these four fields:

* `metadata.title`
* `metadata.subject`
* `metadata.keywords`
* `themes[0].slides`

Every other field is fixed. Do not invent a palette, edit a fixed value, or
introduce a colour outside the pinned set. A deck that appears to need a colour
the palette lacks is a signal to revisit the house style deliberately, across
all levels at once, rather than to improvise a one-level exception that
reopens the drift this file closed.
