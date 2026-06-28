# SwiftUI Component Audit — ThemeKit

**Tip:** (A) Dağıtılabilir SPM kütüphanesi — `ThemeKit` (zero-dependency core) + `ThemeKitLottie` (opt-in add-on).
**Swift / araç:** `swift-tools-version: 6.2`, **ama** `swiftLanguageModes: [.v5]` (Package.swift:son satır).
**Min target:** iOS 17 / macOS 14 (Package.swift:12-15).
**Bağımlılıklar:** core = **0** (native); lottie-ios (yalnız `ThemeKitLottie` target'ı), swift-snapshot-testing (yalnız test target'ı), swift-docc-plugin (yalnız doküman). → Tüketici core'u sıfır bağımlılıkla alır.
**Boyut:** 143 kaynak dosya / 19.022 LOC, **108 component** (26 atom / 37 molekül / 45 organizma), 38 test dosyası.

**Mevcut olgunluk: Level 4 (Production) → Hedef: Level 5 (2026 frontier-modernized).**
> Not: Klasik mimari roadmap'i (`docs/AUDIT.md`) kendi ekseninde tamamlandı (L5) ve v0.2.0 olarak release edildi. Bu rapor **2026 frontier merceğini** uygular ve eksenin yeniden tanımlandığı yeni boşlukları yüzeye çıkarır.

## Snapshot

**En güçlü yan:** Temeller cidden sağlam — zero-dependency core, JSON token pipeline (component'lerde **0 hardcoded renk**), `EnvironmentKey` tabanlı per-subtree theming (6 dosya), `ButtonStyle`-şekilli style protokolleri (3 + 6 ButtonStyle), ve leaf component'ler **%100 binding-driven** (Atoms+Molecules'da 0 ObservableObject/0 @StateObject). Force-unwrap neredeyse yok (4 adet, 0 `try!`/`as!`).

**En büyük risk:** **Concurrency modu sahte-modern.** `swift-tools-version: 6.2` ilan edilmiş ama `swiftLanguageModes: [.v5]` ile derleniyor ve `swiftSettings`'te **0 upcoming feature flag** var — yani Swift 6 strict concurrency hiç zorlanmıyor. Dağıtılabilir bir kütüphane için bu, tüketici Swift 6 modunda derlerken sürpriz data-race uyarıları riski demek.

**En kritik tek iş:** Swift 6 dil moduna geçişi (P0) yapıp çıkan izolasyon hatalarını gidermek — bu, geri kalan frontier işlerinin (Observation, Liquid Glass) üzerine kurulacağı zemin.

## Kategori bazlı bulgular

| Kategori | Durum | Kanıt |
|---|---|---|
| Yapı / modülerlik | **Solid** | 2 ürün, core 0-dep, 1 dosya/component, atoms26/molecules37/organisms45 (Package.swift, Sources/ThemeKit/Components/) |
| API yüzeyi | **Solid** | 844 public / 1466 private+fileprivate / 2 explicit-internal; leaf'ler binding-driven; PR'da `check-api.sh` gate'i (.github/workflows/ci.yml:57) |
| Token sistemi | **Solid** | JSON generator (Theme/ThemeGenerator.swift); component'lerde **0** `Color(red:/hex)`; 6 `Color(hex:)`'in tamamı engine'de (Theme/Shadows.swift:21-23,39 · Theme/Theme.swift:196,220) |
| Theming | **Solid** | `EnvironmentKey` 6 dosya, `.theme(_:)` per-subtree (Theme/ThemeContext.swift); 3 style protokol (CardStyle.swift:29, StatStyle.swift:32, SelectStyle.swift:32) + 6 ButtonStyle |
| State / leaf temizliği | **Solid** | Atoms+Molecules'da **0** ObservableObject/@StateObject; 5 ObservableObject yalnız organism *presenter*'larında (Drawer/Tour/BottomSheet/Upload/Feedback.swift) — leaf VM anti-pattern'i YOK |
| Tip-silme / ölçüm | **Solid** | 31 AnyView/13 dosya (style erasure + heterojen organizma), 12 GeometryReader/9 dosya (slider/progress ölçümü), **4** force-unwrap, 0 `try!`/`as!` |
| `#Preview` / slot | **Solid** | 102 `@ViewBuilder` slot, 114 `#Preview` |
| Dokümantasyon | **Solid** | DocC katalog + 6 article (Sources/ThemeKit/Documentation.docc), 86 struct'ta `///` |
| CI / tooling | **Solid** | ci.yml + docs.yml, .swiftlint.yml + .swiftformat, api-breakage gate PR'da (ci.yml:57) |
| Erişilebilirlik | **Partial** | VoiceOver/RTL var, Reduce Motion **118** kullanım — ama `performAccessibilityAudit` = **0** (otomatik a11y denetimi yok) |
| Test çerçevesi | **Partial** | 34 `XCTestCase`, Swift Testing (`@Test`/`#expect`) = **0**; snapshot 4 suite (~108 component'e karşı, opt-in/iOS-only) |
| **Concurrency (frontier)** | **Solid** ✅ | ~~tools 6.2 ama v5~~ → **Swift 6 dil modu** + 2 upcoming flag (NonisolatedNonsendingByDefault, InferIsolatedConformances); 0 hata / 0 warning, 163 test + Demo yeşil (Package.swift) |
| **Observation (frontier)** | **Solid** ✅ | 6/8 `@Observable`'a taşındı (5 presenter + FormValidator); `@Published` 0, `@StateObject`→`@State`, presenter env'i `@Environment(_.self)`. Yalnız `Theme` (`@unchecked Sendable` singleton + revision-repaint) bilinçli ertelendi |
| **Liquid Glass (frontier)** | **Solid** ✅ | `.glassChrome()` modifier (Extensions/GlassChrome.swift): `.glassEffect` on OS 26+, `Material` fallback 17–25, opaque fill under Reduce Transparency; adopted in Dialog + Drawer chrome. Gated & additive (iOS 17 min korunur) |
| Magic-number spacing | **Partial** | 34 literal `.padding(n)` (token yerine); örn. Molecules/Tooltip.swift:196 `.padding(80)` |
| Preview state-matrix | **Partial** | `PreviewMatrix` helper var (Utils/PreviewMatrix.swift) ama yalnız 3/108 component adopte (Tag/Stat/Avatar); 114 preview'ın çoğu tek-durum |

## Aksiyon planı

### P0 — önce yapılacak ✅ TAMAMLANDI (PR'da)

> Swift 6 dil moduna geçildi (`swiftLanguageModes: [.v6]`) + 2 upcoming flag. 46 strict-concurrency hatası idiomatik fix'lerle çözüldü: 3 style erasure init'inde `sending` parametre, `ThemeContext` `@EnvironmentObject`→`@Environment(\.theme)`, `DateField.text` `nonisolated`, `FormValidator` `@MainActor`. 0 hata / 0 warning, 163 test + Demo yeşil.

**1. Swift 6 dil moduna geç**
- **Ne:** `swiftLanguageModes: [.v6]` + `ThemeKit` target'ına `swiftSettings: [.swiftLanguageMode(.v6)]` ekleyip çıkan strict-concurrency hatalarını gider.
- **Neden:** Şu an tools 6.2 ilan edilip v5 modunda derleniyor → concurrency güvenliği zorlanmıyor; tüketici Swift 6'da derlerken data-race uyarıları patlayabilir. Public kütüphane için en yüksek risk.
- **Efor:** L (Package.swift 1 satır + muhtemel onlarca `@MainActor`/`Sendable` düzeltmesi).
- **Dosyalar:** Package.swift (swiftLanguageModes/swiftSettings) → derleyici güdümünde Sources/ThemeKit genelinde izolasyon fix'leri.

**2. Upcoming feature flag'lerini ekle**
- **Ne:** `swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault"), .enableUpcomingFeature("InferIsolatedConformances")]`.
- **Neden:** Swift 6.2'nin yeni izolasyon davranışlarını erken benimsemek; #1 ile aynı PR'da gider.
- **Efor:** S. **Dosya:** Package.swift.

### P1 — yüksek kaldıraç

**3. `ObservableObject` → `@Observable` (Observation)** — ✅ TAMAMLANDI (Theme hariç)
- **Yapıldı:** 5 presenter (Drawer/Tour/BottomSheet/Upload/Feedback) + FormValidator `@Observable`'a taşındı; `@Published` 0, `@StateObject`→`@State`, presenter enjeksiyonu `.environmentObject`→`.environment` + okuma `@Environment(_.self)`. 163 test + Demo (gerçek tüketici, güncellendi) yeşil.
- **Ertelendi — Theme:** `@unchecked Sendable` singleton, root'ta `@ObservedObject` ile revision-tabanlı repaint (Theme/ThemeKit.swift:45). Core engine olduğundan ayrı odaklı bir çalışma; `@Observable`'a taşımak theming pipeline'ını riske atar.

**4. Otomatik a11y denetimi (`performAccessibilityAudit`)**
- **Ne:** Bir XCUITest target'ı + temsilci ekranlarda `app.performAccessibilityAudit()`.
- **Neden:** Reduce Motion/VoiceOver elle ele alınmış ama kontrast/dokunma-hedefi/dinamik-tip kaçakları otomatik yakalanmıyor.
- **Efor:** M. **Dosyalar:** yeni Tests/ThemeKitUITests/.

**5. Snapshot kapsamını genişlet**
- **Ne:** 4 suite → component grubu başına referans; `ScreenshotGenerator` zaten hepsini render ediyor, golden referansa bağla.
- **Neden:** ~108 component'e karşı 4 suite; theming/regression görsel koruması ince.
- **Efor:** M. **Dosyalar:** Tests/ThemeKitTests/Snapshot/.

**6. Liquid Glass benimseme stratejisi (chrome'da, gated)** — ✅ TAMAMLANDI
- **Yapıldı:** `.glassChrome(in:)` modifier (Extensions/GlassChrome.swift) — `if #available(iOS 26, macOS 26)` ile `.glassEffect(.regular, in:)`, OS 17-25 için `Material`, Reduce Transparency için opak token fill. Dialog card + Drawer paneli chrome'una uygulandı (her ikisi de screenshot baseline'ında değil → churn yok). 163 test + Demo (iOS 26 glass branch'i gerçekten derler) yeşil.
- **Bilinçli kapsam:** Yalnız chrome (floating panel/modal); içerik katmanına dokunulmadı. FAB/Toast/NavigationBar screenshot baseline'ında olduğu için varsayılanları değiştirilmedi — consumer `.glassChrome()`'u istediği chrome'a uygulayabilir.

### P2 — cila

**7. Swift Testing pilotu** — yeni testleri `@Test`/`#expect` ile yaz, mevcut 34 XCTest'i kademeli taşı. **Efor:** S-M. **Dosya:** Tests/ThemeKitTests/.

**8. `PreviewMatrix`'i yaygınlaştır** — 3 → daha fazla component'e `#Preview("States")`. **Efor:** S (mekanik). **Dosya:** Components/ genelinde.

**9. Magic-number padding'leri token'a bağla** — 34 literal `.padding(n)` → `Theme.SpacingKey`. **Efor:** S. **Dosya:** Tooltip.swift:196 ve diğer 33 yer.

## Hızlı kazanımlar (≤30 dk)

- **Upcoming feature flag'leri** ekle (Package.swift `swiftSettings`) — P0#2, tek satır blok.
- **Tooltip.swift:196 `.padding(80)`** → `Theme.SpacingKey` token'ı (en bariz magic number).
- **README/CHANGELOG'a Swift sürüm politikası** notu (tools 6.2 / dil modu hedefi netleşene kadar tüketici beklentisini yönet).
- **`Theme/Shadows.swift`'teki 3 hex shadow** zaten token'lanabilir — generator'a taşımak değerlendir.

## Önerilen sıra

1. **Swift 6 dil modu + upcoming flags** (P0 #1-2) — zemin; diğer her şeyi etkiler.
2. **Observation (`@Observable`)** (P1 #3) — concurrency moduyla doğal eş; presenter'ları modernize eder.
3. **A11y audit + snapshot genişletme** (P1 #4-5) — modernizasyonu regresyona karşı kilitle.
4. **Liquid Glass** (P1 #6) — zemin Swift 6 + gated availability hazırken chrome'a ekle.
5. **Swift Testing + preview matrix + padding token** (P2 #7-9) — cila, mekanik.

---

**Verdict:** Klasik design-system ekseninde referans-grade (zero-dep, token pipeline, style protokoller, env-theming, DocC, CI, api-gate). 2026 frontier merceğinde tek **anti-pattern** concurrency modu (tools 6.2 / dil v5); kalan boşluklar (Observation, Liquid Glass, Swift Testing, a11y-audit) additive modernizasyon — mimari değil. Solid kategorilere iş uydurulmadı.
