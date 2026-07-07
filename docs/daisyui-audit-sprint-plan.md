# daisyUI-Dışı Component Denetimi — Sprint Planı

> 2026-07 denetiminin repo içi kaydı. Satır numaralı bulgu detayları denetim
> artifact'inde tutulur; bu doküman sprint omurgasını, kapsamı ve çıkış
> kriterlerini izler.

## Kapsam ve yöntem

daisyUI'da birebir karşılığı olmayan ~120 component (travel süiti,
medya/dekoratif atomlar, app-shell organizmaları, form ekstraları, takvim)
5 paralel salt-okunur denetimle, 12 kriterlik ev standardına göre incelendi.

**Sonuç:** 17 P0, ~45 P1, ~60 P2 bulgu. Çekirdek desen (token'lar,
copy-on-write modifier'lar, density) oturmuş; asıl sorun desenin eşitsiz
yayılması — aynı işi yapan iki component'ten biri erişilebilir ve
accent'liyken ikizi değil.

## En kritik bulgular (P0) — ✅ 0.10.0'da kapatıldı

> Aşağıda özetlenen (denetim özetinde adı geçen) P0'ların tamamı 0.10.0'da
> kapatıldı. Denetim artifact'inde satır referanslı ek P0 detayı varsa ilk
> mac build + snapshot turunda doğrulanmalı.

- **Ölü API:** `MapCallout` ve `RecentSearchRow`'un `.accent` modifier'ları
  tanımlı ama body'de hiç okunmuyor.
- **Token ihlali:** `PriceHistogram.accent(Color)`, `AmenityGrid.tint(Color)`,
  `EmptyState.iconForeground/Background(Color)` ham `Color` alıyor; demo bile
  token'ı unwrap etmek zorunda kalıyor.
- **Erişilebilirlik engelleri:** `NavigationBar` sekmelerinde etiket yok
  (VoiceOver'a görünmez); `RollingNumber` değer yerine 0-9 iskeletini okuyor;
  `ProgressIndicator` ve `Steps`'te sıfır a11y; Chips ailesi VoiceOver'a buton
  değil; `PriceAlertCard`'ın `.combine`'ı canlı Toggle'ı eziyor.
- **Doğruluk hataları:** `GaugeView` 0…1 dışı aralıkta "%7200" çiziyor;
  `VideoPlayerView` macOS'ta loop/mute/progress'i tamamen düşürüyor;
  `Steps.small()` no-op (iki dal da aynı stil).

## Yeni bulgu — Surface token semantiği (base-100 uyumu) `P1`

daisyUI'ın renk modelinde component'lerin boş zemini **`base-100`**'dür
(*"base surface color of page, used for blank backgrounds"*); `base-200/300`
kademeleri yalnızca girinti/vurgu içindir. ThemeKit'te `base-100`'ün karşılığı
**`bgWhite`**'tır (light: `#fbfdff`, dark: `#181d27`) — ama kart benzeri
component'lerin fiili varsayılanı **`bgElevatorPrimary`** (light: `#e8eff9`,
dark: `#131b29`), yani mavimsi bir elevation tint'i:

- **11 component** `.surface(key)` override'ı sunuyor ama default'u
  `.bgElevatorPrimary`: `PaymentCardField`, `AgentPriceRow`, `AncillaryCard`,
  `BoardingPass`, `FlightTicketCard`, `HotelResultCard`, `MapCallout`,
  `PriceAlertCard`, `RoomCard`, `StickyBookingBar`, `TicketStub`.
- **35 dosya** `.bgElevatorPrimary`'yi doğrudan `.background(...)`'a gömüyor
  (override imkânı yok): `Card`, `DataTable`, `ReviewCard`, `FlightCard`,
  `FlightResultRow`, `LoyaltyCard`, `LocationCard`, `DestinationCard`,
  `FareFamilyCard`, `SheetHeader`, `Footer`, `FilterList`, `InfoBanner`,
  `Callout`, `SearchBar`, `SegmentedControl`, `SelectStyle`, `FieldButton`,
  `FilterGroup`, `FlightRoute`, `InstallmentPicker`, `InstallmentSelector`,
  `RecentSearchRow`, `DatePriceStrip`, `ThemeController`, `BrowserFrame`,
  `PhoneFrame`, `WindowFrame`, `SeatMap`, `SeatMapModels`, `SeatCell`,
  `SwapButton`, `Kbd`, `DividerView`, `Confetti`.

Sonuç: beyaz sayfa üzerinde her kart mavimsi görünüyor; sayfa/zemin hiyerarşisi
daisyUI'ın tersine kurulmuş.

**Yapılan (0.10.0):**

1. ✅ 11 override'lı component'in varsayılanı `.bgWhite`'a çevrildi.
2. ✅ 11 gömülü zeminli kart/surface component'ine `.surface(key)` eklendi
   (`ReviewCard`, `FlightCard`, `FlightResultRow`, `LoyaltyCard`, `LocationCard`,
   `DestinationCard`, `FareFamilyCard`, `SheetHeader`, `Footer`, `FilterList`,
   `RecentSearchRow`). `Card` (`DefaultCardStyle`) ve `DataTable` satırları zaten
   base-100 çıktı; DataTable'ın thead şeridi + zebra satırları bilinçli tint.
3. ✅ Bilinçli tint olarak kalanlar (~24 dosya): seçici/track dolguları
   (`SegmentedControl`, `InstallmentPicker/Selector`, `SelectStyle`, `FieldButton`,
   `SearchBar`, `FilterGroup`, `DatePriceStrip`, `FlightRoute`, `ThemeController`),
   cihaz şasileri (`BrowserFrame`, `PhoneFrame`, `WindowFrame`), koltuk dolguları
   (`SeatCell`, `SeatMap*`), nötr banner varyantları (`Callout`, `InfoBanner`),
   dekoratifler (`Kbd`, `DividerView`, `SwapButton`, `Confetti`). Bunların
   base-100'e çekilip çekilmeyeceği Sprint 4'te tek tek değerlendirilecek.
4. ⏳ Snapshot yenileme CI'sız ortamda yapılamadı — ilk mac build'inde
   re-record gerekir. Migration notu CHANGELOG 0.10.0'da
   (`.surface(.bgElevatorPrimary)` eski görünümü geri getirir).

## Sprint omurgası

| # | Sprint | Kapsam | Çıkış kriteri |
|---|--------|--------|---------------|
| 1 | **P0 temizliği** ✅ *(0.10.0)* | ~20 dosya, tamamı additive: ölü `.accent` API'leri bağlanır, ham `Color` alan API'lere token overload'ları, `NavigationBar`/`RollingNumber`/`ProgressIndicator`/`Steps`/Chips a11y, `GaugeView` clamp, `VideoPlayerView` macOS parity, `Steps.small()` düzeltmesi | 17 P0'ın tamamı kapalı; mevcut çağrı yerleri derlenmeye devam eder |
| 2 | **Motion + 44pt + RTL** | 10 gate'siz animasyona `motionGate`, 12 küçük dokunma hedefine 44pt, LTR-sabit slider/carousel geometrilerine layout-direction desteği | Reduce Motion'da sıfır kayan animasyon; tüm interaktifler ≥44pt; RTL snapshot'ları yeşil |
| 3 | **i18n süpürmesi** | ~50 İngilizce literal (en büyük yüzey SeatMap ailesi); `GuestSelection.summary` çoğullama düzeltmesi | Kullanıcıya görünen literal kalmaz; `verify-i18n` yeşil |
| 4 | **Tema eksenleri + base-100 zemini** *(base-100 kısmı ✅ 0.10.0'da öne çekildi)* | `ComponentDefaults` zinciri (bugün 5 component'te) yaygınlaştırılır; form diliminde `.accent` yalnız `DateRangePicker`'da — diğerlerine eklenir; kalan bilinçli tint'lerin (seçici/track dolguları, cihaz şasileri) base-100 değerlendirmesi | Form component'lerinde tutarlı `.accent`; kart default'ları base-100 ✅; snapshot'lar güncel |
| 5 | **Validasyon yayılımı** | 0.9.0'ın `.validate` katmanı OTP, `InputNumber`, `Date/TimeField`, grup bileşenleri ve `PaymentCardField`'e | Form bileşenlerinin tamamında `.validate` |
| 6 | **Slot ve durumlar** | `DataTable` skeleton satırları, `CardStack` yeniden inşası (hiç modifier'ı yok), `Gallery` overlay, poster/empty durumları | Liste/kart organizmalarında loading-empty-error üçlüsü |
| 7 | **Presenter a11y** | Toast'lar VoiceOver'a duyurulur (announcement), modal'lara Escape + `.isModal` | VoiceOver ile toast/modal akışı tam |
| 8 | **Konsolidasyon** | `InstallmentPicker`+`Selector` birleşmesi, `Counter`↔`CountdownTimer`, varyant sadeleştirme, demo borcu (`TimeField` registry kaydı — tek kayıtsız component) | Registry eksiksiz; mükerrer API kalmaz |
