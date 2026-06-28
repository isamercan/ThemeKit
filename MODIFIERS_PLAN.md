# Modifier Migration Plan — bloated inits → idiomatic SwiftUI modifiers

**FAZ 1 (envanter + plan).** Amaç: şişkin `init`'leri SwiftUI'nin zincirlenebilir modifier
desenine çevirmek; **public API'yi kırmadan** (eski init deprecate + forward). Solid (zaten
ince) API'lere dokunulmaz.

## Envanter (kanıt)

- **103 component**, ortalama **5.2** init parametresi.
- **26 component ≥ 8 parametre** (anti-pattern hedefleri). **51 component ≤ 4** (temiz → dokunulmaz).
- **Precedent:** buton ailesi zaten dönüştürüldü (#96–#98): `isContentWidth`→`block`,
  `isEnabled`→`.disabled()`, label `.lineLimit(1)`. Bu plan aynı deseni yayar.

| Şişkinlik | Component'ler (init param sayısı) |
|---|---|
| 23 | TextInput |
| 12 | ThemeButton✅(done), MultiSelect, DateField |
| 11 | Slider, SearchBar, RadioButton, Badge, Accordion |
| 10 | Rating, RangeSlider, ProgressBar, InputNumber, Chip, Checkbox |
| 9 | VideoPlayerView, SelectBox, Pagination, MultiLineTextInput, Carousel |
| 8 | Stat |

## Karar çerçevesi (özet)

- **KALIR (init):** zorunlu içerik (`title/value/items/url`), `@Binding` (`selection/text/isOn`),
  zorunlu closure (`action/onSubmit`), `@ViewBuilder` slot (`content/label`). Ayrıca *domain
  verisi* sayılan `range/bounds`, `options`, `infoMessages` (gösterilecek validation) ve
  `placeholder` → **kalır** (içerik/veri, görünüm değil).
- **MODIFIER (mekanizma):**
  - **(M-disabled)** `isEnabled: Bool` → SwiftUI native **`.disabled(_:)`** (custom değil; env'den okunur). *En yüksek kaldıraçlı, ~20 component.*
  - **(M-a11y)** `accessibilityID: String?` → self-returning **`.a11yID(_:)`** (kit'in mevcut `.a11y()` altyapısına forward).
  - **(M-style/3)** semantik varyant enum (`style/variant/type/selectionStyle`) → **self-returning** `.componentStyle(_:)` (custom *render* gerekmiyor; sadece semantik renk/emphasis). Açık render genişletmesi gereken yerlerde zaten Style-protokolü var (Card/Stat/Select).
  - **(M-size/3)** `size`/`customSize`/`height` → self-returning `.size(_:)` ya da `ControlSize` kullananlarda native **`.controlSize()`** + `@Environment(\.controlSize)`.
  - **(M-flag/3)** default'lu Bool config bayrakları (`allowClear/showCount/isSecure/showPercentage/gradient/loop/autoplay/searchable…`) → self-returning bayrak modifier'ları.
  - **(M-color/3)** stil renkleri (`textColor/strokeColor/trailColor/backgroundColor/gradient`) → self-returning stil modifier'ları.
  - **(M-env/2)** alt-ağaca cascade etmesi mantıklı çapraz config (yoğunluk) → EnvironmentKey modifier (ör. `.controlSize`, ileride `.fieldDensity`).

> Mekanizma seçimi: çok-varyant açık-render → Style-protokolü (1); cascade → Environment (2);
> tek-instance one-off → self-returning (3). Bu kütüphanedeki çoğu vaka **(3)** veya native env.

---

## En yüksek kaldıraç: çapraz (cross-cutting) migrasyonlar

Bunlar TEK modifier ile ONLARCA component'i sadeleştirir — **önce bunlar yapılmalı**:

### X1 — `isEnabled: Bool` → `.disabled(_:)` (native)
Taşıyan component'ler (init'ten kaldırılıp `@Environment(\.isEnabled)` okunacak; eski param deprecate+forward):
`Chip, Rating, Checkbox, RadioButton, Pagination, DateField, MultiSelect, RangeSlider, SearchBar, SelectBox, Slider, InputNumber, MultiLineTextInput, TextInput` (+ButtonGroup zaten ✅).
**~14 component, tek desen.** Eşleme: `isEnabled: $x` → `.disabled(!x)`; `isEnabled: false` → `.disabled(true)`.

### X2 — `accessibilityID: String?` → `.a11yID(_:)` (self-returning)
Taşıyan: `Checkbox, RadioButton, DateField, MultiSelect, SearchBar, SelectBox, Slider, RangeSlider, InputNumber, MultiLineTextInput, TextInput, Pagination`. **~12 component.** Eski param deprecate+forward `.a11yID(id)`'ye.

### X3 — `size:` → native `.controlSize()` (ControlSize kullananlar)
`Checkbox`, `RadioButton` zaten `ControlSize` alıyor → `@Environment(\.controlSize)` + native `.controlSize()`. Custom size enum'u olanlar (TextInput/Badge/Chip/…) self-returning `.size(_:)`.

---

## Component bazlı plan (26 şişkin)

Lejant: **KALIR** | **→.disabled** | **→.a11yID** | **→style(3)** | **→size** | **→flag(3)** | **→color(3)**

### TextInput (23 → hedef ~6 init)
| Param | Karar | Modifier |
|---|---|---|
| `label`, `text`(Binding), `onSubmit` | **KALIR** | — |
| `placeholder`, `infoMessages` | **KALIR** (içerik/veri) | — |
| `isEnabled` | →.disabled | `.disabled(_:)` |
| `accessibilityID` | →.a11yID | `.a11yID(_:)` |
| `size` | →size | `.size(_:)` (TextInputSize) |
| `isSecure, allowClear, showCount, hardLimit, autocorrectionDisabled` | →flag | `.secure() .clearable() .characterCount(limit:style:) …` |
| `maxLength, countStyle` | →flag (grupla) | `.characterCount(_ max:style:)` |
| `leadingSystemImage, suffixSystemImage, addonBefore, addonAfter` | →style/slot | `.icon(leading:trailing:)` / `.addons(before:after:)` |
| `keyboardType, textContentType, submitLabel, autocapitalization, formatter` | →flag (grupla) | `.keyboard(_:contentType:submit:caps:)` + `.formatter(_:)` |
**Not:** TextInput zaten `TextInputModel` init varyantı taşıyor — model-based init korunur; bloated init `.modifier`'lara bölünür.

### Badge (11 → ~3 init)
| `text`, `action` | **KALIR** |
| `style, variant, size, shape` | →style/size | `.badgeStyle(_:) .badgeVariant(_:) .size(_:) .shape(_:)` (veya tek `.badgeStyle(_, variant:, size:, shape:)`) |
| `leadingSystemImage, trailingSystemImage` | →style | `.icon(leading:trailing:)` |
| `textColor, gradient` | →color | `.tint(_:)` / `.gradient(_:)` (⚠ `.tint` SwiftUI ile çakışmasın → `.badgeColor`) |
| `highlighted` | →flag | `.highlighted(_:)` |

### Chip (10 → ~3)
| `title`, `isSelected`(Binding) | **KALIR** |
| `size, selectionStyle` | →style/size | `.size(_:) .chipStyle(_:)` |
| `leadingSystemImage, rating` | →style | `.icon(_:) .rating(_:)` |
| `isExist, isInteractive, expandsHorizontally` | →flag | `.interactive(_:) .strikethrough(_:) .expands(_:)` |
| `isEnabled` | →.disabled | `.disabled(_:)` |

### Rating (10 → ~3)
| `value`, `onRate, onReviewTap` | **KALIR** |
| `maxValue, size, layout, allowHalf, systemImage` | →style/flag | `.scale(max:) .size(_:) .layout(_:) .allowHalf(_:) .symbol(_:)` |
| `isEnabled` | →.disabled |
| `countLabel, sentiment` | →flag | `.caption(count:sentiment:)` |

### Checkbox / RadioButton (10–11 → ~3)
| `label`, `isChecked/isSelected`(Binding), `infoMessages` | **KALIR** |
| `size`(ControlSize), `customSize` | →controlSize | native `.controlSize()` + `.size(custom:)` |
| `type, style, padding, alignment, backgroundColor` | →style | `.checkboxStyle(_:)` / `.radioStyle(_:)` (type+style+padding+align tek protokol/modifier) |
| `isIndeterminate` | →flag | `.indeterminate(_:)` |
| `isEnabled` | →.disabled · `accessibilityID` | →.a11yID |

### ProgressBar (10 → ~2)
| `value` | **KALIR** |
| `height, gradient, strokeColor, trailColor` | →color/size | `.barHeight(_:) .gradient(_:) .colors(stroke:trail:)` |
| `showPercentage, status, steps, successSegment, format, accessibilityLabel` | →flag | `.percentage(_:) .status(_:) .steps(_:) .successAt(_:) .valueFormat(_:)` |

### Pagination (9 → ~3)
| `current`(Binding), `total` | **KALIR** |
| `simple, siblingCount, boundaryCount, showJumper, jumperTitle, showTotal` | →flag | `.simple(_:) .window(sibling:boundary:) .jumper(title:) .total(_:)` |
| `isEnabled` | →.disabled |

### Accordion (11 → ~3)
| `title`, `content`(@ViewBuilder) | **KALIR** |
| `subtitle, number, leadingSystemImage` | →style/içerik | `.subtitle(_:) .number(_:) .icon(_:)` (veya subtitle/number KALIR — içerik) |
| `indicator, titleSize, paddingSize` | →style/size | `.indicator(_:) .titleSize(_:) .density(_:)` |
| `truncateSubtitle, initiallyExpanded, showDivider` | →flag | `.truncateSubtitle(_:) .expanded(_:) .divider(_:)` |

### Stat (8 → ~3)
| `title, value`, `trend` | **KALIR** (StatStyle layout zaten var ✅) |
| `prefix, suffix, description, systemImage` | →içerik/style | çoğu KALIR (içerik); `systemImage` →`.icon(_:)` |
| `isLoading` | →flag | `.loading(_:)` |

### DateField / SelectBox / MultiSelect / SearchBar / Slider / RangeSlider / InputNumber / MultiLineTextInput
Ortak desen (form/input ailesi):
- **KALIR:** binding (`date/selection/text/value/lowerValue/upperValue`), `options`, `range/bounds`, `optionTitle/isOptionEnabled`, `onChange*/onSubmit/onSearch`, `placeholder`, `infoMessages`, `marks`.
- **→.disabled:** `isEnabled` (hepsi). **→.a11yID:** `accessibilityID` (hepsi).
- **→flag(3):** `allowClear, searchable, isLoading, showInputs, showJumper, showValueTooltip, editable, showBackButton, showMuteToggle, loop, autoplay, muted, debounce, maxTagCount, maxResults, step` → her biri akıcı bayrak modifier (`.clearable() .searchable() .loading() .step(_:) .debounce(_:) …`).
- **→style/size(3):** `style, size, axis, minHeight, verticalHeight, leadingSystemImage, hint, errorText` → stil/boyut modifier (hint/errorText `infoMessages`'a katlanabilir).

### Carousel / VideoPlayerView (medya)
- **KALIR:** `items/url`, `content`(@ViewBuilder), `currentIndex/progress/isMuted`(Binding), `onTap`.
- **→flag(3):** `autoplay, showsArrows, showsDots, loop, fade, dotPosition, muted, showMuteToggle, tapToToggle` → akıcı bayraklar (`.autoplay(_:) .arrows(_:) .dots(_:) .loop(_:) .muted(_:)`).

---

## Temiz component'ler (≤4 param) — DOKUNULMAZ
51 component (Avatar, Tag, Kbd, Spinner, Divider, Icon, StatusDot, Skeleton, Toast, Card, Hero, EmptyState, … + bu plandaki yeni 6: Join/Mask/TextRotate/Gauge/ShareButton/ColorField). Bunlar zaten içerik+binding+action ekseninde ince; **gereksiz değişiklik yapılmaz** (audit kuralı: Solid'e dokunma).

---

## Migration güvenliği

> **Not — repo henüz public değil.** Görev "deprecate+forward" diyor (kütüphane kuralı); ama
> sahibi daha önce "public değil → deprecated kaldır, temiz break" tercih etti. **İki yol:**
> **(A) deprecate+forward** (kurala uygun, source-compatible) — eski init `@available(*, deprecated, message: "Use .x() modifier")` + içeriden yeni API'ye forward.
> **(B) temiz break** (public olmadığından) — eski init kaldır, tüm çağrı yerlerini güncelle (buton ailesinde yaptığımız gibi).
> **Öneri:** public release'e kadar **(B)** (daha temiz, daha az boilerplate); 1.0'da API donunca **(A)**'ya geç. Karar sahibinin.

- Modifier default'ları eski param default'larıyla **birebir** aynı davranır → görsel sonuç değişmez.
- public component → public modifier. Her component sonrası: çağrı yerleri + #Preview + gallery registry + snapshot + DocC güncellenir, `swift build`+`test`+Demo yeşil olmadan sonraki component'e geçilmez.
- SwiftUI çakışan isimlerden kaçın: `.tint/.font/.controlSize` native'leri kullan; semantik renk için `.badgeColor` gibi ayrı isim.

## Önerilen sıra (FAZ 2)
1. **X1 `isEnabled`→`.disabled()`** (14 component, tek desen — en yüksek kaldıraç, en düşük risk).
2. **X2 `accessibilityID`→`.a11yID()`** (12 component).
3. **X3 `size`→`controlSize`/`.size()`**.
4. Sonra component-component **şişkinden sıraya**: TextInput → MultiSelect/DateField → Badge/Chip/RadioButton/Checkbox → ProgressBar/Rating/Pagination/Accordion/Stat → form/medya ailesi.
5. Her component: plan uygula → çağrı yerleri+preview+gallery+test+doc → build/test/Demo yeşil → MODIFIERS_PLAN.md'ye "eski→yeni" eşleme satırı işle.

---

## FAZ 2 — uygulama günlüğü (eski → yeni eşleme)
_(Her component dönüştürüldükçe buraya işlenecek.)_

- **Buton ailesi** ✅ (#96–#98): `isContentWidth: true` → (kaldır, default content-width) · `isContentWidth: false` → `block: true` · `isEnabled: $x` → `.disabled(!x)`.
- **X1 `isEnabled`→`.disabled()`** ✅ (13 component): Chip, Rating, Checkbox, RadioButton, Pagination, DateField, MultiSelect, RangeSlider, SearchBar, SelectBox, Slider, InputNumber, MultiLineTextInput → `@Environment(\.isEnabled)`. Eşleme: `isEnabled: $x`→`.disabled(!x)` · `isEnabled: false`→`.disabled(true)`. **TextInput** (model-tabanlı) kendi refactor'una ertelendi; **RadioButtonGroup/CheckboxGroup/SegmentedControl/ThemeToggle** X1 kapsamı dışı (round 2).
