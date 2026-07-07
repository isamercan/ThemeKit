# ThemeKit Esneklik Programı — FAZ 3 Kapanış Raporu

> 2026-07-07 · Program tamamlandı: 0.10.0 → 0.16.0, **32 commit**, 6 dalga,
> ~30 paralel ajan koşusu. Hedef ölçüt: *bir tasarımcı Figma'da hangi varyasyonu
> çizerse çizsin, component fork edilmeden modifier + slot + style ile o
> varyasyon üretilebilmeli.* Envanter ve hedef API'ler: `flexibility-audit-faz1.md`.

## 1. Sayısal özet

| Metrik | Önce (FAZ 1) | Sonra |
|---|---|---|
| Style protokolü | 3 (Card/Select/Stat) | **9** — + ListRowStyle, FieldStyle, ChipStyle, BarStyle, MeterStyle, ToastStyle (SelectStyle deprecated köprü) |
| `@ViewBuilder` slot modifier'ı | ~14 | **42** |
| Not-5 component (3 katman tam) | 3 | **40+** (style-bağlı aile üyeleri) |
| Not-1 component (sıfır modifier) | 16 | **2** (HeroSurface, StepIndicator — gerekçeli) |
| Kontrollü deprecation | 0 | **28** (hepsi çalışır durumda, mesajlı) |
| Ham `Color` alan vurgu API'si | 17 | **0 aktif** (hepsi deprecated + token muadilli) |

## 2. Katman 3 — kim hangi kapıdan geçiyor

| Protokol | Built-in'ler | Bağlı component'ler |
|---|---|---|
| `CardStyle` *(genişletildi: isSelected/isPressed/surfaceKey/radius)* | `.default` `.outlined` | Card + 16 kart organizması (Hotel/Flight/Room/Destination/Location/Ancillary/Review/Blog/Notification/PriceAlert/FareFamily/Radio/Checkbox/DatePrice/KeyValueTable/Loyalty-arka yüz) |
| `FieldStyle` | `.default` `.underlined` | TextInput + 14 form alanı (Select ailesi, Date/TimeField, InputNumber, OTP, PaymentCard, File, Color, MultiLine, Search ailesi, FieldButton) |
| `ListRowStyle` | `.default` `.inset` | ListRow |
| `ChipStyle` *(isDefault köprülü)* | `.tonal` `.solid` | Chip + Image/Compact/Chose/FilterChip + MapPriceMarker |
| `BarStyle` *(isDefault köprülü)* | `.default` `.floating` | SheetHeader, Footer + PageHeader/NavigationBar/StickyBookingBar (köprü) |
| `MeterStyle` *(isDefault köprülü)* | `.linear` `.striped` `.radial` | ProgressBar, RadialProgress |
| `ToastStyle` *(isDefault köprülü)* | `.default` `.capsule` | AlertToast (feedbackHost dahil) |
| `StatStyle` | mevcut | Stat |
| `SelectStyle` | *deprecated* | Select (custom enjekte edilirse legacy yol) |

**isDefault köprüsü deseni:** DefaultXStyle'ın üretemeyeceği özgün kroması olan
component'ler (kapsül tab bar, görsel-üstü seçim çerçevesi, radial halka),
environment'ta custom style yokken bugünkü görünümü bit-birebir korur; custom
style set edilir edilmez kroma tamamen `makeBody(configuration:)`'a geçer.

## 3. Katman 1 — slot envanteri (yeni eklenenler)

`.leading{}` / `.trailing{}`: ListRow, TextInput, Chip, SheetHeader, NotificationCard, ListSectionHeader ·
`.media{}` / `.overlay{}`: HotelResultCard, LocationCard, DestinationCard, BlogCard ·
`.item{}` (per-item): NavigationBar · `.marker{}` (per-step): Steps ·
`.empty{}` / `.loadingView{}`: ListView, DataTable, Gallery · `.header{}`/`.footer{}`: DataTable ·
Custom içerik overload'ları: `toast{}`, `notify{}`, `dialog{}`, `popconfirm{}`, `tourHost(stepCard:)` (+ `TourStepContext`).

## 4. Katman 2 — standardizasyon

- **`accent(_: SemanticColor?)` tek renk fiili** — 18 component'e eklendi;
  `color/fillColor/ringColor/badgeColor/colors/tint/selectionColor` deprecated.
  Badge bilinçli istisna: semantik kapısı `badgeStyle`.
- **Geometri token'ları:** `cornerRadius(RadiusRole)`, `spacing/peek(SpacingKey)`
  overload'ları; ham CGFloat knob'lar meşru geometri ekseni olarak kaldı (dokümante).
- **`fullWidth`** standardı: `Chip.expands`, `Coupon.block` → deprecated-renamed.
- **Devre dışılık:** `Chip.interactive` deprecated → native `.disabled(_:)`.
- **Not-1 tabanı kaldırıldı:** Breadcrumbs, FilterGroup, ScoreBadge, TextRotate,
  FareFeatureRow, ShareButton, CalendarView, ThemeController, ThemePicker, SortTab,
  Counter (`CounterSize`), ListSectionHeader — hepsi copy-on-write modifier katmanı kazandı.
- **`copy(_:)` normalizasyonu:** Carousel, VideoPlayerView.

## 5. Gerekçeli istisnalar (fork-suzluk başka kapıdan)

| Component | Neden | Esneklik yolu |
|---|---|---|
| TicketStub, Coupon, FlightTicketCard, BoardingPass | Delikli/kesikli bilet kabuğu = kimlik (`destinationOut` oyma) | content/stub slotları + Katman-2 |
| LoyaltyCard ön yüzü | Marka gradient'i | arka yüz CardStyle'da; `gradient(_:)` ekseni |
| Dialog/Feedback/Tour kabukları | Perde üstü yüzen modal kroması — ambient `.outlined` okunmazlık yaratır | custom içerik overload'ları |
| GaugeView | Native SwiftUI `Gauge` geometrisi | Katman-2 |
| Sidebar, SegmentedControl/TabBar, TripTypeToggle, FilterBar, SortSummaryBar | Bar kroması yok / track+seçim kontrol kroması | Katman-2 |
| Badge/Tag ailesi | Variant sistemi zaten stil ekseni, seçim durumu yok | `badgeStyle`/`tagStyle` + `variant` |
| GuestSelector, CurrencyPicker, RatingSummary, HeroSurface | Alan kutusu/kabuk yok ya da mevcut slot yeterli | Katman-2 / üst component slotu |

## 6. Bilinen görsel normalizasyonlar (snapshot yenileme gerekçeleri)

1. Gölgeli kart kabuklarında hairline artık çizilmiyor (Card semantiği: hairline = `.none`).
2. `stroke` → `strokeBorder` (yarım piksel içe).
3. Seçili kart çerçeveleri `borderHero` 1.5pt'ye normalize (kart-başına accent/2pt yerine).
4. Form ailesi: disabled dolgu tek tip `bgSecondaryLight`; error/warning odak border'ını yener ve 1.5pt; köşeler `.field` rol token'ında (bundled temalarda aynı değer).
5. SearchBar/FieldButton dolguları `bgElevatorPrimary` → `bgWhite` (base-100 programının devamı).
6. OTP dolu-pasif hücre `borderHero` → `borderPrimary`.

## 7. Kanıt

Demo → **"Flexibility Showcase"** galeri sayfası: 6 pilot + kart/form/chip-bar-meter
aile bölümleri; her biri *default / slotlar dolu / demo hedefinde tanımlı custom
style* üçlüsüyle. Custom style'ların kütüphane dışında yazılabilmesi fork-suzluk
hedefinin kanıtıdır.

## 8. Kalan işler (program dışı)

- mac'te `swift build` + snapshot yeniden kaydı (bilinçli normalizasyonlar §6).
- Demo'daki 2 deprecated çağrı (`.expands`, `.block`) + `.selectStyle(.filled)` uyarıları — kozmetik.
- Buton ailesi ButtonStyle köprüsü (onaylı karar, ayrı iş) ve orijinal denetimin
  Sprint 2-3-7-8'i (motion/44pt/RTL, i18n, presenter a11y, konsolidasyon) planda duruyor.
