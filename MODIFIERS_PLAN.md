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
- **TextInput** ✅ (X1+X2 ertelemesi kapatıldı): `isEnabled`→`@Environment(\.isEnabled)` (native `.disabled()`), `accessibilityID`→`.a11yID()` modifier. İkisi de `TextInputModel`'den + flat init'ten kaldırıldı; View `@Environment(\.isEnabled)` + `private var accessibilityID` tutuyor (6× `model.isEnabled`→`isEnabled`, 6× `model.accessibilityID`→`accessibilityID`). Çağrı yerleri: MoleculeDemos (7 model, per-mode `demoA11yID` switch + `.a11yID()`), MoreDemos (2 form field), TextInput #Preview (2) + Accessibility.swift doc örneği. **Tam 23→6 teardown VERİ-TEMELLİ REDDEDİLDİ:** 23 call-site'ın **11'i `TextInputModel(...)`** config-bundle'ı kullanıyor (solid escape-hatch), flat init param'ları call-site'larda seyrek (en çok 3, çoğu 1), `isEnabled` 0 kullanım. 15 stil/flag param'ını 15 modifier'a bölmek 11 model call-site'ını kırardı + marjinal fayda → "Solid'i bozma / gereksiz değişiklik yapma" gereği model korundu, sadece cross-cut tutarlılığı uygulandı.
- **InputNumber** ✅ (11→8 init, veri-temelli — minimal): 8 call-site → çoğu param **gerçekten kullanılıyor** (label 9×, range 7×, unit 6×, step 5×, large 4×, hint 3×) → init'te KALIR ("gereksiz değişiklik yapma"). Sadece seyrek/ölü: `editable` 2×, `hasInfo` 0×, `onChange` 0× → modifier: `.editable(_:) .hasInfo(_:) .onValueChange(_:)` (`.onValueChange` SwiftUI `.onChange(of:)` ile karışmasın diye). Çağrı yerleri: MoleculeDemos demo (2× `.editable`).
- **SearchBar** ✅ (14→8 init ×2, veri-temelli + ihtiyatlı): 2 init (classic + async `suggest`). `text/placeholder/suggestions/recent` (content/data) + **interaction callback'leri** (`onSearch/onSelect/onSubmit/onClearRecent`) init'te KALIR (component'in kontratı; ayrıca `onSubmit` SwiftUI native `.onSubmit` ile çakışırdı). **Chrome+tuning** → modifier: `.backButton(_:action:)` (showBackButton+onBack), `.trailingIcon(_:action:)` (trailingSystemImage+onTrailing), `.debounce(_:)`, `.maxResults(_:)`. Async init `debounce=0.3` baseline'ı init gövdesinde set ediyor (`.debounce(_:)` override edebilir) — per-init default korundu. Çağrı yerleri: MoreDemos demo (`.backButton/.trailingIcon`), 2 #Preview.
- **Accordion** ✅ (11→4 init, veri-temelli): 7 call-site → `initiallyExpanded` 5× (+ `@State expanded` seed'i, init'te kalmalı), `leadingSystemImage` 3× **init'te kalır** (+ title/content @ViewBuilder); `subtitle`/`truncateSubtitle`/`showDivider` 0×, `number`/`indicator`/`titleSize`/`paddingSize` 1× → modifier: `.subtitle(_:) .number(_:) .indicator(_:) .titleSize(_:) .density(_:) .truncateSubtitle(_:) .divider(_:)` (`.density` = paddingSize; SwiftUI `.padding` çakışmasından kaçınıldı). Tek call-site (OrganismDemos demo) modifier'lara çevrildi.
- **Rating** ✅ (10→3 init, veri-temelli): 9 call-site → `layout` 5×, `countLabel` 6× **init'te kalır** (+ content `value`); `allowHalf` 3×, `size`/`onReviewTap` 2×, `systemImage`/`onRate` 1×, `maxValue`/`sentiment` 0× → modifier: `.maxValue(_:) .starSize(_:) .allowHalf(_:) .symbol(_:) .sentiment(_:) .onRate(_:) .onReviewTap(_:)`. Optional callback'ler (`onRate/onReviewTap`) idiomatic `.onRate{} .onReviewTap{}` modifier'larına geçti (trailing closure korunur). Çağrı yerleri: AtomDemos demo, ComponentRegistry usage string, #Preview.
- **Chip** ✅ (10→4 init, veri-temelli): X1 Chip'te `@Environment(\.isEnabled)` eklemiş ama init'te **ölü `isEnabled` param'ı** bırakmıştı (atanmıyordu, sessizce yok sayılıyordu — bug riski) → kaldırıldı. 16 call-site: `selectionStyle` 6×, `size` 3× **init'te kalır** (+ title/isSelected); `leadingSystemImage/rating/isExist/expandsHorizontally` 1×, `isInteractive` 0× → modifier: `.icon(_:) .rating(_:) .exists(_:) .interactive(_:) .expands(_:)`. Tek call-site (AtomDemos Chip demo) modifier showcase'ine çevrildi + #Preview (`.icon`).
- **ProgressBar** ✅ (11→3 init, veri-temelli): 17 call-site ölçüldü → `showPercentage` 12×, `status` 5× **init'te kalır** (+ content `value`); `height` 3×, `gradient` 3×, `steps` 2×, `strokeColor`/`trailColor`/`successSegment` 1×, `format`/`accessibilityLabel` 0× → modifier: `.barHeight(_:) .gradient(_:) .steps(_:) .colors(fill:track:) .successSegment(_:) .valueFormat(_:) .progressLabel(_:)`. (strokeColor+trailColor `.colors(fill:track:)`'te gruplandı; successSegment clamp'i modifier'a taşındı.) Çağrı yerleri: Upload (`barHeight`), AtomDemos demo (5 modifier showcase), DisplaySnapshotTests (`.gradient()` — görsel aynı, snapshot geçerli), #Preview.
- **Badge** ✅ (11→6 init, veri-temelli): call-site yoğunluğu ölçüldü (36 site) → `style` 33×, `leadingSystemImage` 11×, `size` 10×, `variant` 4× **init'te kalır** (gerçek kullanım); `shape` 2×, `textColor` 1×, `trailingSystemImage`/`gradient`/`highlighted` **0×** → self-dönen modifier'lara taşındı: `.badgeShape(_:) .trailingIcon(_:) .badgeColor(_:) .gradient(_:) .highlighted(_:)`. (`.badgeColor` SwiftUI `.tint/.foregroundColor` ile çakışmasın diye ayrı isim.) Tek call-site (AtomDemos Badge demo, tüm long-tail'i knob'larla kullanan) modifier showcase'ine çevrildi + #Preview. Churn ~2 site.
- **X3 `size`→`.controlSize()`** ✅ (3 component — ControlSize üçlüsü): Checkbox, RadioButton, ThemeToggle. ThemeKit'in `public enum ControlSize` (small/medium) custom enum'u SwiftUI'nin `ControlSize`'ını **gölgeliyordu** (collision); kaldırıldı. Üçü de native `ControlSize` + `@Environment(\.controlSize)` + native `.controlSize(_:)` cascade'ine geçti. `size` init param'ı kaldırıldı. Metrik: `extension ControlSize { var checkboxSide }` (`.mini/.small`→20, default `.regular`→24) Checkbox+RadioButton'da; ThemeToggle track'i `isCompact` (32×20 / 40×24). Eşleme: `size: .small`→`.controlSize(.small)` · `size: .medium`→(kaldır, native default `.regular`=eski `.medium`=24, görsel aynı) · `size: small ? .small : .medium`→`.controlSize(small ? .small : .regular)`. `customSize: CGFloat?` (Checkbox piksel escape-hatch) init'te kaldı. Çağrı yerleri: TreeSelect, MultiSelect, MoleculeDemos(Checkbox/RadioButton/ThemeToggle demo). **Kalan size param'ları** (Avatar/Badge/Chip/Divider/ListRow/ProgressIndicator/SegmentedControl/Select/Rating/RadialProgress + buton/TextInput) component-özel enum'lar → component-component fazında ele alınacak (tek mekanik cross-cut değil).
- **X2 `accessibilityID`→`.a11yID()`** ✅ (21 component): SelectBox, Autocomplete, CheckboxGroup, RadioGroup, SegmentedControl, RangeSlider, SearchBar, Select, RadioButton, ToggleGroup, Slider, ThemeToggle, OTPInput, InputNumber, Checkbox, DateField, MultiSelect, MultiLineTextInput, QuantityStepper, Swap, SegmentedTabBar. Mekanizma: stored `accessibilityID` → `private var … = nil` (namespace gizli kalır), init param'ı kaldırıldı, self-dönen `func a11yID(_ id: String?) -> Self` modifier'ı eklendi (`var copy = self; copy.accessibilityID = …; return copy`). Eşleme: `accessibilityID: "x"` → trailing `.a11yID("x")`. Çağrı yerleri: DateField/Select/Checkbox demo'ları taşındı. **TextInput** (model-tabanlı) + **buton ailesi** (`ButtonConfiguration` intermediary; accessibilityID init param'ı korunur) X2 dışı.
