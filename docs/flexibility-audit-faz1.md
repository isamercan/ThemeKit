# ThemeKit Esneklik Denetimi — FAZ 1 Raporu

> 2026-07-07 · Salt analiz, kod değişikliği yok. Hedef ölçüt: bir tasarımcı Figma'da
> hangi varyasyonu çizerse çizsin, component **fork edilmeden** yalnız
> modifier + slot + style ile o varyasyon üretilebilmeli.
> FAZ 2 bu rapordaki taslakların onayından sonra başlar.

## 1. Yöntem ve rubrik

192 public component/kayıt, 5 paralel salt-okunur taramayla incelendi
(Atoms + Calendar · Molecules A–L · Molecules M–Z · Organisms A–L · Organisms M–Z).

Üç katman arandı:

| Katman | Tanım | Kanıt |
|---|---|---|
| **1 — Slot** | `@ViewBuilder` ile dışarıdan view enjeksiyonu (`.leading{}`, `.footer{}`, content builder) | `AnyView?` property + builder modifier |
| **2 — Config** | Copy-on-write chainable modifier'lar, token-tipli parametreler | tek `copy(_:)` mutasyon noktası |
| **3 — Style** | `protocol XStyle { makeBody(configuration:) }` + environment injection; built-in varyantlar da aynı protokolden geçer | `Configuration` + `AnyXStyle` erasure + `.xStyle(_:)` |

**Not rubriği:** 1 = sabit init, modifier yok · 2 = kısmi modifier / ham tipler ·
3 = tam Katman-2 (token disiplinli) · 4 = 3 + gerçek slot · 5 = 4 + Style protokolü.

## 2. Sonuç dağılımı

| Not | Adet | Oran | Anlamı |
|---|---|---|---|
| **5** | 3 | %2 | `Card`, `Select`, `Stat` — üç katman tam |
| **4** | 37 | %19 | Slot + config var, Style protokolü yok |
| **3** | 108 | %56 | Katman-2 tam, slot yok |
| **2** | 28 | %15 | Kısmi modifier / ham tip sızıntısı / presenter |
| **1** | 16 | %8 | Sabit init, sıfır modifier |

Okuma: kütüphanenin omurgası (Katman-2, copy-on-write, token disiplini) zaten
kurulu — sorun eşitsiz dağılım. Style protokolü deseni üç yerde ispatlanmış
ama yayılmamış; slot deseni organizmalarda yaygın, molekül/atom katında seyrek.

## 3. Referans ilanı

**Referans: `Card` + `CardStyle`** — kütüphanede üç katmanı birden taşıyan tek
component ailesi. 5 almasını sağlayan özellikler:

1. **Sorumluluk ayrımı:** `Card` yalnız içeriği (header + body + loading) kurar;
   kabuk (fill, border, shadow, radius) tamamen `CardStyle.makeBody(configuration:)`'a
   devredilmiş.
2. **ButtonStyle idiomu birebir:** `CardStyleConfiguration(content: AnyView,
   elevation:)` → `AnyCardStyle` erasure → `EnvironmentKey` → `.cardStyle(_:)` +
   `where Self ==` statik kısayollar (`.default`, `.outlined`).
3. **Built-in'ler aynı kapıdan geçiyor:** `DefaultCardStyle` ve `OutlinedCardStyle`
   protokolün sıradan implementasyonları — dış dünya ne yapabiliyorsa built-in'ler de onu yapıyor.
4. Content `@ViewBuilder` slotu + config modifier'ları (`elevation`, `loading`, `extraAction`).

**Bileşik ideal (FAZ 2 şablonu):** Card'ın Katman-3 tesisatı +
`RoomCard`/`DateRangePicker`'ın slot genişliği (footer/media/per-item builder;
DateRangePicker'da 5 slot) + `Select`'in **durum taşıyan** Configuration'ı
(`isOpen/isEnabled/hasError/hasWarning` — kroma state'e tepki verebiliyor).
Yani hedef Configuration: `slotlar (AnyView?) + config state (size, variant,
isSelected, isPressed, isEnabled…)`.

Kullanıcı tahmini `ListItem` (bizde `ListRow`) referans **değil**: 14 config
modifier'la en zengin Katman-2 örneği, ama `trailing`'i view değil enum alıyor,
gerçek slotu ve Style protokolü yok → Not 3. FAZ 2'de B arketipinin pilotu olacak.

## 4. Tam envanter

### 4a. Atoms + ThemeKitCalendar (47 kayıt)

| Ad | Dosya | Init (param) | Slot'lar | Mod# | Modifier adları | Style | Ham tip sızıntısı | Not |
|---|---|---|---|---|---|---|---|---|
| AnimatedImage | Atoms/AnimatedImage.swift | 1 (`_ url: URL?`) | — | 2 | contentMode, cornerRadius | — | cornerRadius(CGFloat) | 3 |
| Aura | Atoms/Aura.swift | 0 | — | 3 | color, size, intensity | — | size(CGFloat) | 3 |
| Avatar | Atoms/Avatar.swift | 1 (`_ content`) | — | 5 | size, dimension, fillColor, shape, presence | — | dimension(CGFloat) | 3 |
| AvatarGroup | Atoms/Avatar.swift | 1 (`_ avatars`) | — | 3 | size, maxVisible, fillColor | — | — | 3 |
| Badge | Atoms/Badge.swift | 2 (`_ text, action?`) | — | 9 | badgeStyle, variant, size, icon, badgeShape, trailingIcon, badgeColor, gradient, highlighted | — | badgeColor(Color?), gradient([Color]?) | 3 |
| Barcode | Atoms/Barcode.swift | 1 | — | 2 | height, showsValue | — | height(CGFloat) | 3 |
| Chip | Atoms/Chip.swift | 2 (`_ title, isSelected:`) | — | 7 | size, chipStyle, icon, rating, exists, interactive, expands | — | — | 3 |
| CodeBlock | Atoms/CodeBlock.swift | 1 | — | 1 | copyable | — | — | 3 |
| Confetti | Atoms/Confetti.swift | 0 | — | 3 | pieceCount, colors, duration | — | — | 3 |
| Ribbon | Atoms/CountBadge.swift | 2 (`_ text, @VB content`) | content (wrap) | 1 | color | — | — | 4 |
| CountdownTimer | Atoms/CountdownTimer.swift | 1 (`until:`) | expired (@VB) | 7 | style, format, size, showsDays, urgentBelow, onExpired, onFinish | — | — | 4 |
| DividerView | Atoms/DividerView.swift | 1 | — | 4 | size, axis, dashed, titleAlign | — | — | 3 |
| FareFeatureRow | Atoms/FareFeatureRow.swift | 1/4 | — | 0 | — | — | — | 1 |
| FlightStatusBadge | Atoms/FlightStatusBadge.swift | 1 | — | 4 | time, label, showsIcon, solid | — | — | 3 |
| GaugeView | Atoms/GaugeView.swift | 3 | — | 2 | gaugeStyle, showsValue | — | — | 3 |
| Icon | Atoms/Icon.swift | 1 | — | 2 | size, color | — | color(Color?) | 3 |
| IconTile | Atoms/IconTile.swift | 1 | — | 6 | size, iconSize, background(key), iconColor(key), accent, cornerRadius(role) | — | size/iconSize(CGFloat) | 3 |
| InlineText | Atoms/InlineText.swift | 2 | — | 2 | color, inlineStyle | — | color(Color?) | 3 |
| InputLabel | Atoms/InputLabel.swift | 1 | — | 3 | required, hasInfo, hasError | — | — | 3 |
| Join | Atoms/Join.swift | 2 (`axis, @VB content`) | content | 0 | — | — | — | 3 |
| Kbd | Atoms/Kbd.swift | 1 | — | 1 | size | — | — | 3 |
| PointsBadge | Atoms/PointsBadge.swift | 1 | trailing (@VB) | 7 | unit, style, size, icon, showsSign, animatesValue, trailing | — | — | 4 |
| PriceTag | Atoms/PriceTag.swift | 2 | trailing (@VB) | 12 | original, unit, size, emphasis, discountBadge, fractionDigits, free, soldOut, prefix, from, animatesValue, trailing | — | — | 4 |
| ProgressBar | Atoms/ProgressBar.swift | 1 | — | 9 | showsPercentage, status, barHeight, gradient, steps, colors, successSegment, valueFormat, progressLabel | — | colors(Color?), barHeight(CGFloat) | 3 |
| StepIndicator | Atoms/ProgressBar.swift | 2 | — | 0 | — | — | — | 1 |
| QRCode | Atoms/QRCode.swift | 1 | — | 1 | size | — | size(CGFloat) | 3 |
| RadialProgress | Atoms/RadialProgress.swift | 1 | — | 8 | size, lineWidth, showsLabel, status, dashboard, accent, ringColor, a11yLabel | — | ringColor(Color?), size/lineWidth(CGFloat) | 3 |
| Rating | Atoms/Rating.swift | 1 | — | 9 | layout, countLabel, maxValue, starSize, allowHalf, symbol, sentiment, onRate, onReviewTap | — | starSize(CGFloat) | 3 |
| RemoteImage | Atoms/RemoteImage.swift | 1 (+2 overload) | — | 4 | ratio, contentMode, cornerRadius, circle | — | ratio(CGFloat?), cornerRadius(CGFloat) | 3 |
| RollingNumber | Atoms/RollingNumber.swift | 1 | — | 3 | size, weight, color | — | color(Color?), weight(Font.Weight), size(CGFloat) | 3 |
| ScoreBadge | Atoms/ScoreBadge.swift | 2 | — | 0 | — | — | — | 1 |
| SearchBadge | Atoms/SearchBadge.swift | 1 | — | 2 | colors(bg/fg key), icon | — | — | 3 |
| SeatCell | Atoms/SeatCell.swift | 11 (dev init) | customContent (init closure) | 0 | — | — | size(CGFloat), AnyView closure | 2 |
| ShareButton | Atoms/ShareButton.swift | 2 | — | 0 | — | — | — | 1 |
| Skeleton | Atoms/Skeleton.swift | 1 | — | 1 | size(width:height:) | — | size(CGFloat) | 3 |
| Spinner | Atoms/Spinner.swift | 0 | — | 5 | style, size, lineWidth, accent, color | — | color(Color?), size/lineWidth(CGFloat) | 3 |
| StatusDot | Atoms/StatusDot.swift | 2 | — | 2 | size, pulse | — | size(CGFloat) | 3 |
| Swap | Atoms/Swap.swift | 1 | — | 4 | symbols, size, rotate, a11yID | — | size(CGFloat) | 3 |
| SwapButton | Atoms/SwapButton.swift | 2 | — | 2 | size, bordered | — | size(CGFloat) | 3 |
| Tag | Atoms/Tag.swift | 2 | — | 3 | icon, tagStyle, variant | — | — | 3 |
| TextLink | Atoms/TextLink.swift | 2 | — | 2 | underline, accent | — | — | 3 |
| TextRotate | Atoms/TextRotate.swift | 2 | — | 0 | — | — | — | 1 |
| TiltCard | Atoms/TiltCard.swift | 1 (`@VB content`) | content | 3 | maxAngle, shine, radius(role) | — | — | 4 |
| Title | Atoms/Title.swift | 1 | — | 3 | subtitle, eyebrow, action | — | — | 3 |
| TimeWheel | Calendar/TimeWheel.swift | 3 binding | — | 1 | format | — | — | 3 |
| DateRangePicker | Calendar/DateRangePicker.swift | 4 | **day, selectedAccessory, monthHeader, weekdayHeader, legend (5×@VB)** | 27 | display, accent, daySelection, selectionMode, horizontalPaging, bare, showsWeekdayHeader, showsFooter, showsLegend, showsTitleBar, showsDateRow, showsTodayButton, prices, maxDate, blockedDates, initialRange, nights, holidays, holiday, locale, calendar, customizeStyle… | — (customizeStyle escape hatch var, protokol yok) | — | 4 |

### 4b. Molecules A–L (34 kayıt)

| Ad | Dosya | Init | Slot'lar | Mod# | Modifier adları | Style | Ham tip sızıntısı | Not |
|---|---|---|---|---|---|---|---|---|
| AmenityGrid | AmenityGrid.swift | 1 | — | 6 | columns, size, tint×2, limit, highlighted | — | tint(Color?) (token overload var) | 3 |
| Autocomplete | Autocomplete.swift | 4 | — | 6 | placeholder, maxResults, debounce, suggestionEnabled, onSearch, a11yID | — | — | 3 |
| Breadcrumbs | Breadcrumbs.swift | 2 | — | 0 | — | — | — | 1 |
| ButtonGroup | Buttons/ButtonGroup.swift | 2 (`axis, @VB content`) | content | 0 | — | — | — | 2 |
| PrimaryButton | Buttons/Buttons.swift | 2 (+async) | — | 7 | size, fullWidth, helperText, titleTextStyle, confirmsSuccess, a11yID, loading | — | — | 3 |
| SecondaryButton | Buttons/Buttons.swift | 2 (+async) | — | 7 | (aynı set) | — | — | 3 |
| OutlineButton | Buttons/Buttons.swift | 2 (+async) | — | 7 | (aynı set) | — | — | 3 |
| GhostButton | Buttons/Buttons.swift | 2 (+async) | — | 7 | (aynı set) | — | — | 3 |
| LinkButton | Buttons/Buttons.swift | 2 | — | 2 | size, a11yID | — | — | 2 |
| CalendarView | CalendarView.swift | 1 | — | 0 | — | — | — | 1 |
| Checkbox | Checkbox.swift | 2 | — | 7 | type, indeterminate, alignment, customSize, accent, infoMessages, a11yID | — | customSize(CGFloat?) | 3 |
| CheckboxGroup | CheckboxGroup.swift | 4 | — | 4 | infoMessages, selectAll, optionEnabled, a11yID | — | — | 3 |
| ImageChip | Chips.swift | 2 | — | 1 | size | — | — | 2 |
| CompactChip | Chips.swift | 3 | — | 2 | imageURL, rating | — | — | 2 |
| ChoseChip | Chips.swift | 2 | — | 4 | description, rating, free, icon | — | — | 3 |
| FilterChip | Chips.swift | 2 | — | 2 | shape, closable | — | — | 2 |
| ChipGroup | Chips.swift | 4 | — | 1 | chipStyle | — | — | 2 |
| ColorField | ColorField.swift | 2 | — | 1 | supportsOpacity | — | Binding\<Color\> (ColorPicker gereği) | 2 |
| CurrencyPicker | CurrencyPicker.swift | 2 | — | 3 | showsName, searchable, recents | — | — | 3 |
| DateField | DateField.swift | 2 | — | 9 | placeholder, range, style, locale, components, infoMessages, clearable, icon, a11yID | — | — | 3 |
| DatePriceCard | DatePriceStrip.swift | 3 | — | 2 | currency, cheapest | — | — | 2 |
| DatePriceStrip | DatePriceStrip.swift | 2 | — | 4 | currency, columns, highlightCheapest, onPage | — | — | 3 |
| Dropdown | Dropdown.swift | 2 (`items, @VB trigger`) | **trigger** | 3 | edge, accent, menuWidth | — | menuWidth(CGFloat?) | 4 |
| FieldButton | FieldButton.swift | 2 | — | 4 | label, icon, trailing, placeholder | — | — | 3 |
| Fieldset | Fieldset.swift | 2 (`title, @VB content`) | content | 1 | helper | — | — | 3 |
| FileInput | FileInput.swift | 2 | — | 5 | fileName, buttonTitle, placeholder, infoMessages, onClear | — | — | 3 |
| FilterGroup | FilterGroup.swift | 4 | — | 0 | — | — | — | 1 |
| FilterRow | FilterRow.swift | 2 | — | 3 | count, icon, showsSeparator | — | — | 3 |
| FlightRoute | FlightRoute.swift | 4 | — | 3 | stops, nextDay, pathColor | — | — (pathColor token key) | 3 |
| GuestSelector | GuestSelector.swift | 1 | — | 8 | showsRooms, showsInfants, adultRange, childRange, infantRange, roomRange, maxTotal, onChange | — | — | 3 |
| InputNumber | InputNumber.swift | 3 | — | 9 | step, unit, hint, errorText, large, editable, hasInfo, onValueChange, a11yID | — | — | 3 |
| InstallmentPicker | InstallmentPicker.swift | 2 | — | 2 | currency, accent | — | — | 2 |
| InstallmentSelector | InstallmentSelector.swift | 4 | — | 3 | interestFreeUpTo, recommended, surcharge | — | — | 3 |
| LayoverRow | LayoverRow.swift | 2 | — | 4 | warning, layoverLabel, icon, accent | — | — | 3 |

### 4c. Molecules M–Z (40 kayıt)

| Ad | Dosya | Init | Slot'lar | Mod# | Modifier adları | Style | Ham tip sızıntısı | Not |
|---|---|---|---|---|---|---|---|---|
| MapPriceMarker | MapPriceMarker.swift | 1 | — | 4 | selected, accent, icon, pointer | — | — | 3 |
| MultiLineTextInput | MultiLineTextInput.swift | 2 | — | 8 | placeholder, characterLimit, countStyle, size, errorText, infoMessages, minHeight, a11yID | — | minHeight(CGFloat) | 2 |
| MultiSelect | MultiSelect.swift | 4 | — | 8 | placeholder, infoMessages, optionEnabled, searchable, clearable, maxTags, loading, a11yID | — | — | 3 |
| OTPInput | OTPInput.swift | 2 | — | 6 | digitCount, secure, errorText, infoMessages, resend, a11yID | — | — | 3 |
| Pagination | Pagination.swift | 2 | — | 4 | simple, window, jumper, showTotal | — | — | 3 |
| PassengerRow | PassengerRow.swift | 2 | — | 9 | type, subtitle, seat, status, avatar, icon, onEdit, accessory, accent | — | — | 3 |
| PaymentCardField | PaymentCardField.swift | 3 | — | 4 | holder, accent, surface, placeholders | — | — | 3 |
| PriceBreakdown | PriceBreakdown.swift | 2 | — | 8 | original, discountBadge, unit, note, extra, size, emphasis, align | — | — | 3 |
| PriceHistogram | PriceHistogram.swift | 4 | — | 6 | barHeight, accent×2, currency, resultCount, showsBounds | — | barHeight(CGFloat), accent(Color?) | 2 |
| PriceTrendChart | PriceTrendChart.swift | 2 | — | 15 | title, currency, accent, selectionColor, barHeight, barWidth, spacing, cornerRadius, scrollable, maxDays, showsAxis, showsValues, showsWeekday, gradient, onPage | — | barHeight/barWidth/spacing(CGFloat) | 2 |
| ProgressIndicator | ProgressIndicator.swift | 3 | — | 4 | size, videoProgress, stepText, cornerRadius | — | — | 3 |
| QuantityStepper | QuantityStepper.swift | 2 | — | 2 | a11yID, step | — | — | 3 |
| RadioButton | RadioButton.swift | 2 (+tag overload) | — | 8 | type, radioStyle, gap, fillColor, accent, infoMessages, alignment, a11yID | — | fillColor(Color?) | 2 |
| RadioGroup | RadioGroup.swift | 4 | — | 3 | infoMessages, optionEnabled, a11yID | — | — | 3 |
| RadioButtonGroup | RadioGroup.swift | 3 | — | 4 | groupStyle, fullWidth, optionEnabled, a11yID | — | — | 3 |
| RangeSlider | RangeSlider.swift | 3 | — | 6 | a11yID, step, marks, inputs, onChangeEnd, valueLabel | — | — | 3 |
| RecentSearchRow | RecentSearchRow.swift | 3 | — | 8 | roundTrip, dates, passengers, icon, onRemove, accent, bordered, surface | — | — | 3 |
| ScrubGallery | ScrubGallery.swift | 2 | **content (per-index @VB)** | 3 | indicator, accent, radius | — | — | 4 |
| SearchBar | SearchBar.swift | 1/2 | — | 11 | placeholder, suggestions, recent, onSearch, onSelect, onCommit, backButton, trailingIcon, debounce, maxResults, a11yID | — | — | 3 |
| SearchField | SearchField.swift | 2 | **content{}, accessory{}** | 18 | value, dateRange, passengers, icon, iconColor, trailing, onClear, background, borderColor, cornerRadius, focused, showsShadow, chipColors, titleStyle, subtitleStyle, placeholderColor… | — | — (tümü token key) | 4 |
| SeatLegend | SeatLegend.swift | 3 | — | 1 | showsPremium | — | — | 2 |
| SegmentedControl | SegmentedControl.swift | 2 (×2) | — | 3 | fullWidth, size, a11yID | — | — | 3 |
| **Select** | Select.swift | 4 | — (kroma style ile) | 8 | placeholder, clearable, searchable, size, infoMessages, loading, optionEnabled, a11yID | **SelectStyle ✓** | — | **5** |
| SelectBox | SelectBox.swift | 4 | — | 4 | placeholder, hint, errorText, a11yID | — | — | 3 |
| Slider | Slider.swift | 3 | — | 6 | a11yID, step, marks, axis, showsValueTooltip, onChangeEnd | — | axis(_, height:CGFloat) | 2 |
| SmartSuggestion | SmartSuggestion.swift | 1 | — | 6 | label, icon, tint, onTap, action, bordered | — | — | 3 |
| SortSummaryBar | SortSummaryBar.swift | 2 | — | 1 | onMore | — | — | 2 |
| SortTab | SortSummaryBar.swift | 3 | — | 0 | — | — | — | 1 |
| **Stat** | Stat.swift | 2 | — (kroma style ile) | 6 | prefix, suffix, loading, description, icon, trend | **StatStyle ✓** | — | **5** |
| StepperRow | StepperRow.swift | 2 | — | 5 | subtitle, range, step, icon, accent | — | — | 3 |
| Steps | Steps.swift | 2 | — | 3 | axis, small, progressDot | — | — | 3 |
| SuggestionRow | SuggestionRow.swift | 2 | **trailing{}** | 11 | icon, iconColor, iconTile, code, subtitle, nested, selected, highlight, accessory, trailing, accent | — | — | 4 |
| TextInput | TextInput.swift | 2 (+model) | — | 21 | placeholder, icon, addons, secure, clearable, maxLength, showsCount, size, formatter, helperText, errorText, warningText, infoMessages, validate×2, onValidation, externalFocus, keyboard, autocorrectionDisabled, onCommit, a11yID | — | — | 3 |
| ThemeController | ThemeController.swift | 2 | — | 0 | — | — | — | 1 |
| ThemeToggle | ThemeToggle.swift | 1 | — | 4 | loading, symbols, accent, a11yID | — | — | 3 |
| TimeField | TimeField.swift | 2 | — | 9 | placeholder, range, minuteInterval, hourCycle, locale, infoMessages, clearable, icon, a11yID | — | — | 3 |
| ToggleGroup | ToggleGroup.swift | 4 | — | 2 | optionDescription, a11yID | — | — | 3 |
| TreeSelect | TreeSelect.swift | 4 | — | 5 | placeholder, cascade, searchable, loading, nodeEnabled | — | — | 3 |
| TripTypeToggle | TripTypeToggle.swift | 2 | — | 3 | icons, accent, fullWidth | — | — | 3 |

### 4d. Organisms A–L (40 kayıt)

| Ad | Dosya | Init | Slot'lar | Mod# | Modifier adları | Style | Ham tip sızıntısı | Not |
|---|---|---|---|---|---|---|---|---|
| Accordion | Accordion.swift | 3 (`title, expanded, @VB content`) | content | 8 | icon, subtitle, number, indicator, titleSize, density, truncateSubtitle, divider | — | — | 4 |
| AccordionGroup | AccordionGroup.swift | 4 | content (per-item) | 1 | mode | — | — | 4 |
| AgentPriceRow | AgentPriceRow.swift | 2 | — | 13 | logo, icon, subtitle, rating, badge, warning, price, original, cta, recommended, accent, surface, cornerRadius | — | — | 3 |
| AlertToast | AlertToast.swift | 1 | — | 6 | message, variant, icon, loading, action, onClose | — | — | 3 |
| AncillaryCard | AncillaryCard.swift | 1 | — | 10 | icon, image, subtitle, price, badge, quantity, added, accent, surface, cornerRadius | — | — | 3 |
| BlogCard | BlogCard.swift | 2 (`title, @VB media`) | media | 3 | excerpt, readMore, compact | — | — | 4 |
| BoardingPass | BoardingPass.swift | 3 | — | 15 | airline, flightNo, cabin, cities, times, date, details, gate, bookingRef, passengerLabel, barcode, qr, accent, surface, elevation | — | — | 3 |
| BrowserFrame | BrowserFrame.swift | 2 (`url, @VB content`) | content | 2 | elevation, accent | — | — | 4 |
| Callout | Callout.swift | 1 | — | 5 | variant, calloutStyle, showsIcon, action, onClose | — | — | 3 |
| **Card** | Card.swift | 3 (`title, action, @VB content`) | content | 5 | subtitle, elevation, contentPadding, extraAction, loading | **CardStyle ✓** | contentPadding(CGFloat) | **5** |
| CardStack | CardStack.swift | 2 | content (per-item) | 0 | — | — | — | 1 |
| Carousel | Carousel.swift | 4 (+activeContent) | content (per-item) | 4 | autoplay, arrows, dots, fade | — | — | 4 |
| ChatBubble | ChatBubble.swift | 3 | — | 3 | side, icon, accent | — | — | 3 |
| Counter | Counter.swift | 1/3 | — | 0 | — | — | — | 1 |
| Coupon | Coupon.swift | 3 | — | 6 | couponStyle, size, icon, discount, expiry, block | — | — | 3 |
| DataTable | DataTable.swift | 3 | hücre (Column @VB → AnyView) | 4 | striped, pageSize, loading, onRowTap | — | — | 4 |
| DestinationCard | DestinationCard.swift | 2 | media, footer | 14 | surface, subtitle, price, rating, ribbon, badge, tags, favorite, aspect, overlayTitle, onTap, media, footer, elevation | — | aspect(CGFloat) | 4 |
| Diff | Diff.swift | 2 (`@VB before, @VB after`) | before, after | 1 | aspect | — | aspect(CGFloat) | 4 |
| EmptyState | EmptyState.swift | 1 (+image/animated) | — (media enum) | 10 | icon, message, imageMaxHeight, iconForeground×2, iconBackground×2, iconCircleSize, primaryAction, secondaryAction | — | Color/CGFloat escape-hatch'ler (token overload'lu) | 3 |
| FareFamilyCard | FareFamilyCard.swift | 2 | footer | 8 | surface, currency, accent, features, selected, selection, onSelect, footer | — | — | 4 |
| FareSummary | FareSummary.swift | 2 | footer | 2 | onInfo, footer | — | — | 4 |
| FilterBar | FilterBar.swift | 2 | — | 6 | onFilter, onSort, collapsible, size, accent, spacing | — | spacing(CGFloat) | 3 |
| FilterList | FilterList.swift | 2 | — | 5 | title, bordered, showsSeparators, selectAll, surface | — | — | 3 |
| FlightCard | FlightCard.swift | 5 (+legs) | footer | 10 | surface, stops, price, airlineIcon, badge, onSelect, favorite, scarcity, fareBrand, footer | — | — | 4 |
| FlightResultRow | FlightResultRow.swift | 5 | — | 17 | surface, flightNo, cabin, stops, returnLeg, addLeg, price, airlineIcon, airlineLogo, baggage, badge, favorite, bookmark, totalPrice, urgency, onSelect, onDetails | — | — | 3 |
| FlightTicketCard | FlightTicketCard.swift | 2 | — | 11 | cities, times, duration, stops, airline, airlineLogo, price, favorite, accent, elevation, surface | — | — | 3 |
| FloatingActionButton | FloatingActionButton.swift | 3 | — | 3 | shape, color, badge | — | — | 3 |
| Footer | Footer.swift | 2 | — | 1 | surface | — | — | 3 |
| Gallery | Gallery.swift | 2 | content (per-item) | 2 | columns, aspect | — | — | 4 |
| Hero | Hero.swift | 2 (`title, @VB background`) | background | 3 | subtitle, cta, dark | — | — | 4 |
| HeroSurface | Hero.swift | — | — | 0 | — | — | — | 1 |
| HotelResultCard | HotelResultCard.swift | 1 | footer | 22 | image, images, location, score, reviewsSuffix, features, promos, price, original, discountBadge, stay, extraDiscount, badge, favorite, onSelect, footer, accent, imageHeight, cornerRadius, elevation, surface, showsPageDots | — | imageHeight(CGFloat) | 4 |
| ImageCollage | ImageCollage.swift | 2 | — | 3 | height, spacing, cornerRadius | — | hepsi ham CGFloat | 2 |
| InfoBanner | InfoBanner.swift | 3 | — | 5 | variant, showsIcon, fullWidth, action, onDismiss | — | — | 3 |
| KeyValueTable | KeyValueTable.swift | 1 | — | 2 | title, bordered | — | — | 3 |
| ListRow | ListRow.swift | 2 | — (trailing enum) | 14 | subtitle, number, size, icon, leadingImage, leadingSelection, alertCount, badge, meta, infos, selected, multilineTitle, trailing, onInfo | — | — | 3 |
| ListSectionHeader | ListRow.swift | 1 | — | 0 | — | — | — | 1 |
| ListView | ListView.swift | 2 | row (per-item) | 6 | header, footer, bordered, loading, split, emptyText | — | — | 4 |
| LocationCard | LocationCard.swift | 2 (×2) | — | 10 | surface, subtitle, distance, mapHeight, spanMeters, onTap, pois, directions, onDirections, snapshot | — | mapHeight(CGFloat) | 3 |
| LoyaltyCard | LoyaltyCard.swift | 2 | logo | 10 | surface, memberName, unit, progress, icon, gradient, animatesValue, membership, flippable, logo | — | gradient([Color]?) | 4 |

*(View içermeyen dosyalar: BottomSheet, ButtonDock, Dialog, Drawer, Feedback → presenter/extension; CardStyle → protokol.)*

### 4e. Organisms M–Z (31 kayıt)

| Ad | Dosya | Init | Slot'lar | Mod# | Modifier adları | Style | Ham tip sızıntısı | Not |
|---|---|---|---|---|---|---|---|---|
| MapCallout | MapCallout.swift | 1 | — | 8 | image, subtitle, score, price, onSelect, accent, surface, pointer | — | — | 3 |
| MenuCard | MenuCard.swift | 2/1 | — | 2 | subtitle, icon | — | — | 2 |
| NavigationBar | NavigationBar.swift | 2 | — | 0 | — | — | — | 1 |
| NotificationCard | NotificationCard.swift | 2 (`title, @VB actions`) | actions (footer) | 5 | message, date, unread, variant, onClose | — | — | 4 |
| PageHeader | PageHeader.swift | 1 | — | 4 | subtitle, tags, onBack, actions | — | — | 3 |
| PagingCarousel | PagingCarousel.swift | 2 | content (per-item) | 3 | peek, spacing, autoplay | — | peek/spacing(CGFloat) | 4 |
| PhoneFrame | PhoneFrame.swift | 1 (`@VB content`) | content | 2 | notch, bezel | — | — | 4 |
| PriceAlertCard | PriceAlertCard.swift | 2 | — | 7 | subtitle, icon, price, trend, accent, surface, cornerRadius | — | — | 3 |
| PromoBanner | PromoBanner.swift | 2 | — | 4 | subtitle, icon, ctaTitle, color | — | — | 3 |
| RatingSummary | RatingSummary.swift | 1 | — | 2 | label, reviews | — | — | 2 |
| ResultView | ResultView.swift | 2 | — | 3 | message, primaryAction, secondaryAction | — | — | 3 |
| ReviewCard | ReviewCard.swift | 3 | actions (footer) | 9 | surface, date, title, verified, photos, stars, expandable, onPhotoTap, actions | — | — | 4 |
| RoomCard | RoomCard.swift | 1 | footer | 16 | image, board, occupancy, features, price, original, unit, discountBadge, badge, selection, onSelect, footer, accent, cornerRadius, elevation, surface | — | — | 4 |
| SeatMap | SeatMap.swift | 2/4 | seatLabel (per-seat) | 15 | maxSelection, seatSize, showsLabels, legend, fuselage, showsSeatInfo, recommended, currency, seatEnabled, passengers, zoomable, seatDisplay, seatLabel, aisleWidth, tierColors | — | seatSize/aisleWidth(CGFloat), tierColors([SeatTier:Color]) | 4 |
| SegmentedTabBar | SegmentedTabBar.swift | 4 (×2) | — | 3 | scrollable, tabStyle, a11yID | — | — | 3 |
| RadioCard | SelectionCards.swift | 3 | — | 1 | description | — | — | 2 |
| CheckboxCard | SelectionCards.swift | 3 | — | 1 | description | — | — | 2 |
| SheetHeader | SheetHeader.swift | 1 | trailing | 8 | subtitle, onBack, onClose, progress, trailing, showsDivider, accent, surface | — | — | 4 |
| Sidebar | Sidebar.swift | 2 (×2) | header, footer | 4 | header, footer, width, a11yID | — | width(CGFloat?) | 4 |
| StickyBookingBar | StickyBookingBar.swift | 2 | leading | 10 | price, original, note, discountBadge, ctaIcon, enabled, accent, surface, showsShadow, leading | — | — | 4 |
| ThemePicker | ThemePicker.swift | 3 | — | 0 | — | — | — | 1 |
| TicketStub | TicketStub.swift | 1 (`@VB content`) | content, stub | 8 | stub, perforation, notchRadius, cornerRadius, elevation, surface, dashColor, contentPadding | — | notchRadius(CGFloat) | 4 |
| Timeline | Timeline.swift | 1 | — | 4 | axis, mode, reversed, pending | — | — | 3 |
| Toast | Toast.swift | presenter (5 param) | — | 0 | — | — | autoDismiss(Double) | 2 |
| Tour | Tour.swift | presenter/manager | — | 0 | — | — | — | 2 |
| Popconfirm | Popconfirm.swift | presenter (~9 param) | — | 0 | — | — | — | 2 |
| Upload | Upload.swift | 5 | — | 2 | buttonTitle, maxCount | — | — | 2 |
| UploadList | Upload.swift | 2 | — | 2 | prompt, buttonTitle | — | — | 2 |
| UploadController | Upload.swift | manager | — | 0 | — | — | — | 2 |
| VideoPlayerView | VideoPlayerView.swift | 5 | — | 5 | autoplay, loop, muted, muteToggle, tapToToggle | — | — | 3 |
| WindowFrame | WindowFrame.swift | 2 (`title, @VB content`) | content | 2 | elevation, accent | — | — | 4 |

## 5. Arketipler ve hedef API taslakları

192 component'e tek tek protokol yazmak yerine **arketip bazlı** hedef tanımlıyoruz:
her component bir arketipe üye; arketipin slot seti, modifier standardı ve
(anlamlıysa) paylaşımlı Style protokolü onun hedef API'sidir. İstisnalar satır
içinde notlanır.

### B. Liste satırı → `ListRowStyle` *(pilot arketip)*

**Üyeler:** ListRow, SuggestionRow, RecentSearchRow, PassengerRow, LayoverRow,
FilterRow, StepperRow, AgentPriceRow, MenuCard, FareFeatureRow, SortTab, ListSectionHeader.

```swift
ListRow("Otel Adı")
    .subtitle("Deniz manzaralı")
    .leading { RemoteImage(thumb) }                    // YENİ slot (icon/leadingImage overload olarak kalır)
    .trailing { Badge("%20").variant(.success) }       // YENİ slot (mevcut trailing enum'u overload olur)
    .listRowStyle(.inset)                              // YENİ Katman 3

public protocol ListRowStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: ListRowStyleConfiguration) -> Body
}
public struct ListRowStyleConfiguration {
    public let leading: AnyView?
    public let content: AnyView          // başlık + alt başlık + meta (dizilmiş)
    public let trailing: AnyView?
    public let isSelected: Bool
    public let isEnabled: Bool
    public let size: ListRowSize
}
// Built-in'ler: .plain (bugünkü), .inset (bordered kart satır), .compact
```

### C. Kart → mevcut `CardStyle`'ı benimseme

**Üyeler:** HotelResultCard, FlightCard, FlightResultRow, RoomCard, DestinationCard,
LocationCard, FareFamilyCard, ReviewCard, BlogCard, AncillaryCard, PriceAlertCard,
NotificationCard, LoyaltyCard, BoardingPass, FlightTicketCard, TicketStub, MapCallout,
DatePriceCard, RadioCard, CheckboxCard, RatingSummary, Coupon, KeyValueTable.

Yeni protokol YOK — kart organizmaları dış kabuğunu `CardStyleConfiguration`
üzerinden `\.cardStyle`'a devreder (0.10.0'daki `surface()` bunun Katman-2 ön adımıydı).
`CardStyleConfiguration`'a additive state eklenir: `isSelected`, `isPressed`
(seçilebilir kartlar için). Slot standardı: `.media{} .header{} .footer{} .overlay{}`.

```swift
HotelResultCard(name: "Mirage Park")
    .media { MapSnapshot(coordinate) }     // YENİ (image/images overload kalır)
    .overlay { Ribbon("Son 2 oda") }       // YENİ
    .footer { AmenityGrid(list).columns(3) } // mevcut
    .cardStyle(.outlined)                  // YENİ — Card ile aynı kapı
```

### D. Form alanı → `FieldStyle` (SelectStyle'ın genellemesi)

**Üyeler:** TextInput, MultiLineTextInput, Select, SelectBox, MultiSelect, TreeSelect,
DateField, TimeField, InputNumber, OTPInput, PaymentCardField, FileInput, ColorField,
SearchBar, SearchField, Autocomplete, CurrencyPicker, FieldButton, GuestSelector.

```swift
public struct FieldStyleConfiguration {
    public let content: AnyView            // label + değer + accessory (dizilmiş)
    public let isFocused: Bool             // (Select'te isOpen buna eşlenir)
    public let isEnabled: Bool
    public let hasError: Bool
    public let hasWarning: Bool
    public let size: TextInputSize
}
// SelectStyle → FieldStyle'ın deprecated typealias'ı olur; DefaultFieldStyle
// bugünkü DefaultSelectStyle kromasının birebir taşınmışı.
// Slotlar: .leading{} / .trailing{} (TextInput.addons bunların overload'ı olur).
```

### A. Chip/rozet → `ChipStyle`

**Üyeler:** Chip, ImageChip, CompactChip, ChoseChip, FilterChip, ChipGroup, Tag,
Badge, SearchBadge, FlightStatusBadge, MapPriceMarker, PointsBadge, ScoreBadge.

Configuration: `content, isSelected, isEnabled, size`. Built-in'ler mevcut
`ChipSelectionStyle` (.tonal/.solid) buraya taşınır. Slotlar: `.leading{}` `.trailing{}`.
ImageChip/CompactChip/ChoseChip aynı kromayı paylaşır (bugün üçü ayrı ayrı çiziyor).

### E. Bar/kabuk → `BarStyle`

**Üyeler:** SheetHeader, PageHeader, NavigationBar, StickyBookingBar, FilterBar,
SortSummaryBar, Footer, SegmentedTabBar, SegmentedControl, TripTypeToggle, Sidebar.

Configuration: `leading, content, trailing (AnyView?), attachedEdge`. Slot standardı:
`.leading{} .trailing{}` (+ NavigationBar'a `.item{}` per-item builder).

### F. Gösterge/sayaç → `MeterStyle` + Katman-2 tamamlama

**Üyeler:** ProgressBar, ProgressIndicator, RadialProgress, GaugeView, StepIndicator,
Steps, Timeline, Pagination, Rating, RollingNumber, CountdownTimer, Counter,
PriceTrendChart, PriceHistogram, SeatLegend.

`MeterStyleConfiguration(fraction, status, label: AnyView?)` — ProgressBar/RadialProgress/
GaugeView/StepIndicator paylaşır. Steps/Timeline'a per-item `.marker{}` slotu;
Rating'e `.symbol{}` slotu. Counter ↔ CountdownTimer birleşmesi (denetim sprint 8) burada yapılır.

### G. Presenter → içerik slotu + aile protokolü

**Üyeler:** Toast/AlertToast, Popconfirm, Dialog, BottomSheet, Drawer, Feedback, Tour, Dropdown.

Her presenter'a custom-view overload (`.toast(isPresented:) { MyToastView() }`) +
`ToastStyle`/`DialogStyle` (Configuration: message, variant, icon, actions).
Chainable olmayan çok-parametreli presenter API'leri korunur, config struct'a taşınır.

### H. Konteyner → slot tamamlama (çoğunlukla Katman 1-2)

**Üyeler:** Accordion, AccordionGroup, Carousel, PagingCarousel, ScrubGallery, Gallery,
ImageCollage, ListView, DataTable, CardStack, Join, ButtonGroup, Fieldset, FareSummary,
Diff, Hero, TiltCard, BrowserFrame, PhoneFrame, WindowFrame, CodeBlock, Upload ailesi.

Eksik slotlar: `.empty{}` ve `.loadingView{}` (ListView/DataTable/Gallery),
`.header{}/.footer{}` (DataTable), CardStack yeniden inşası (0 modifier → tam Katman 1-2).
Style protokolü zorlanmaz (rapor kısıtı: anlamsızsa uygulama).

### I. Buton ailesi → native `SwiftUI.ButtonStyle` köprüsü

Primary/Secondary/Outline/Ghost/Link beşlisi bugün 4 ayrı struct + ortak modifier seti.
Öneri: tek `TKButtonStyle` tabanı üzerinden native `.buttonStyle(.tkPrimary)` /
`.tkSecondary`… conformance'ları; mevcut struct'lar deprecated sarmalayıcı olarak kalır.
(Karar noktası #2 — aşağıda.)

### J. Katman-2-yeterli (slot/style bilinçli olarak YOK)

Icon, IconTile, Avatar/AvatarGroup, Spinner, Skeleton, DividerView, Kbd, QRCode,
Barcode, AnimatedImage, RemoteImage, Aura, Confetti, InlineText, InputLabel, Title,
TextRotate, Swap, SwapButton, StatusDot, ShareButton, Breadcrumbs, SmartSuggestion,
Callout, InfoBanner, PromoBanner, EmptyState, ResultView, ThemeToggle, ThemePicker,
ThemeController, CalendarView, TimeWheel, QuantityStepper, RangeSlider, Slider,
Checkbox/Radio/Toggle grupları, VideoPlayerView, FloatingActionButton, SeatCell*.

Bunlarda hedef: Katman-2'yi tamamla (eksik modifier, ham tip temizliği, Not ≥3),
Not-1'leri (ScoreBadge, StepIndicator, FareFeatureRow, TextRotate, Breadcrumbs,
CalendarView, FilterGroup, ThemePicker, ThemeController, SortTab, Counter,
ListSectionHeader, HeroSurface, NavigationBar†) modifier setine kavuştur.
*SeatCell dev-init'i SeatMap'in `.seat{}` builder'ına katlanır. †NavigationBar E arketipinde.

## 6. Modifier isim standardı (aynı kavram = aynı fiil)

| Kavram | Standart imza | Değişecek mevcutlar (deprecated olur) |
|---|---|---|
| Vurgu rengi | `accent(_: SemanticColor?)` | `Icon.color`, `Spinner.color`, `InlineText.color`, `RollingNumber.color`, `RadialProgress.ringColor`, `Badge.badgeColor`, `RadioButton.fillColor`, `Avatar.fillColor`, `ProgressBar.colors`, `AmenityGrid.tint(Color)`, `SmartSuggestion.tint`, `PriceTrendChart.selectionColor`, `PriceHistogram.accent(Color?)`, `FloatingActionButton.color`, `PromoBanner.color`, `Aura.color`, `Ribbon.color` |
| Zemin | `surface(_: Theme.BackgroundColorKey)` | `SearchField.background` → `surface` |
| Köşe | `cornerRadius(_: Theme.RadiusRole)` | ham `CGFloat` alan tüm `cornerRadius/radius` (AnimatedImage, RemoteImage, ImageCollage, PriceTrendChart, TicketStub.notchRadius) |
| Boyut | `size(_: <X>Size)` enum; kaçış: `.custom(CGFloat)` case | ham CGFloat `size/height/width/dimension/starSize/barHeight/imageHeight/mapHeight/minHeight/seatSize/aisleWidth/peek/lineWidth/iconCircleSize` |
| Aralık | `spacing(_: Theme.SpacingKey)` | ham CGFloat `spacing` (FilterBar, PagingCarousel, ImageCollage) |
| Tam genişlik | `fullWidth(_ on: Bool = true)` | `Chip.expands`, `Coupon.block` |
| Devre dışı | `@Environment(\.isEnabled)` (native `.disabled`) | `Chip.interactive`, `StickyBookingBar.enabled`, `InputNumber.editable` |
| Yükleme | `loading(_ on: Bool = true)` | ✓ zaten yaygın |
| Görünürlük | `showsX(_ on: Bool = true)` | `Barcode.showsValue` ✓, tekilleştirme gerekmez |
| Eylem | `onX(_ action:)` | ✓ |
| Varyant | `variant(_:)` (semantik), `xStyle(_:)` (Katman 3 kroma) | `Badge.badgeStyle`, `Tag.tagStyle`, `Coupon.couponStyle` → Katman 3'e taşınırken ad `xStyle` biçiminde standarttır |
| Slot | `leading/trailing/header/footer/media/overlay/empty { }` — `func x<V: View>(@ViewBuilder _ content: () -> V) -> Self` | `ListView.header(String)` gibi metin sürümleri overload olarak kalır |
| Mutasyon | tek `private func copy(_:)` | `Carousel`, `VideoPlayerView` inline `var copy = self` → standarda çekilir |

## 7. Ham tip sızıntısı temizliği

Envanterdeki tüm ham `Color`/`CGFloat`/`Font.Weight` API'leri (bkz. sütun) şu kuralla
kapanır: token/enum overload eklenir, ham sürüm `@available(*, deprecated)` işaretlenir,
gövdesi yeni API'yi çağırır. 0.10.0'da PriceHistogram/AmenityGrid/EmptyState için
uygulanan desenin aynısı (~35 dosya).

## 8. Karar noktaları (onay öncesi)

1. **Style protokolü granülaritesi.** Spec'in harfi "her component'e bir protokol"
   (~90 protokol) → önerimiz **arketip-paylaşımlı 8 protokol** (ListRowStyle,
   FieldStyle, ChipStyle, BarStyle, MeterStyle, ToastStyle, DialogStyle + mevcut
   CardStyle/StatStyle) + karmaşık tekillere özel (DataTable, SeatMap,
   DateRangePicker'ın `customizeStyle`'ı gerçek protokole dönüşür). Aynı fork'suz
   esneklik, ~%90 daha az API yüzeyi. **Onay?**
2. **Buton ailesi.** (a) 4 struct kalır + `TKButtonStyle` ortak protokolüne oturur,
   (b) tek `Button` + `.variant(...)` + deprecated sarmalayıcılar. Önerimiz (a) —
   native SwiftUI `ButtonStyle` ile köprü, call-site kırılmaz. **Onay?**
3. **FAZ 2 yürütmesi.** ~190 component tek PR'da değişmez. Önerimiz 6 dalga
   (aşağıda); her dalga *mac'te* `swift build` + snapshot + Catalog showcase ile
   kapanır. Bu remote ortamda Swift toolchain YOK — build/snapshot doğrulaması
   senin tarafında veya CI'da koşulmalı. **Onay + build'i kimin koşacağı?**

## 9. FAZ 2 dalga planı (onaylandı — kararlar: arketip-paylaşımlı protokoller ✓, butonlar 4 struct + native ButtonStyle köprüsü ve tam zenginlikte ✓, dalga sonu build kullanıcıda ✓)

| Dalga | Kapsam | Kanıt |
|---|---|---|
| 1 ✅ *(0.11.0)* | Arketip protokolleri tanımlanır + 6 pilot (ListRow, TextInput, Chip, SheetHeader, ProgressBar, HotelResultCard) | Catalog "Flexibility Showcase" ilk 6 girişi: default / zengin slot / custom style |
| 2 ✅ *(0.12.0)* | C arketipi: kart organizmaları CardStyle'a bağlandı (16 adopt + 7 gerekçeli istisna/kısmi), media/overlay slotları | showcase "Card family" bölümü: tek custom style birden çok kartı yeniden giydiriyor |
| 3 ✅ *(0.13.0)* | D arketipi: 15 form alanı FieldStyle'a (SelectStyle deprecated köprüyle katlandı; GuestSelector/CurrencyPicker istisna) | showcase "Form family" bölümü |
| 4 ✅ *(0.14.0)* | A+E+F: chip/bar/gösterge aileleri (isDefault köprüleriyle; Badge/Tag ailesi + segment kontrolleri gerekçeli K2 istisnası) | showcase güncellendi |
| 5 | G+H: presenter içerik slotları + konteyner empty/loading slotları + CardStack inşası | showcase |
| 6 | İsim standardı süpürmesi (deprecation'lar), ham tip temizliği, Not-1 tabanı, rapor + önce/sonra tablosu | tam CatalogView + özet rapor |

---

**FAZ 1 çıktısı burada biter — kod değişikliği yapılmadı. FAZ 2, yukarıdaki 3 karar
noktasının onayıyla başlar.**
