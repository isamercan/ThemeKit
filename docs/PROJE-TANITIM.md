# ThemeKit — Proje Tanıtımı

> **Tek cümlede:** Figma tasarım token'larından beslenen, koddan tek satır değişmeden
> herhangi bir markaya/temaya bürünebilen, sıfır 3. parti bağımlılığı olan kurumsal bir
> SwiftUI bileşen kütüphanesi.

---

## 1. Neden var? (Çözdüğü problem)

Her ekip kendi butonunu, input'unu, kartını yeniden yazıyor. Sonuç: tutarsız UI, kopyala-yapıştır
borç, marka değişiminde haftalarca elle düzeltme, her projede tekrar eden erişilebilirlik/lokalizasyon işi.

**ThemeKit bunu tek bir token-tabanlı kaynağa indirger:**
- Tasarımcı Figma'da rengi değiştirir → JSON token güncellenir → tüm uygulama otomatik döner.
- Yeni proje açılır → kütüphaneyi `import` eder → ilk günden 65+ hazır, tutarlı bileşene sahip olur.
- Marka/tema değişimi kod değişikliği değil, **konfigürasyon** meselesi olur.

---

## 2. Bir bakışta (rakamlar)

| | |
|---|---|
| **Üretime hazır bileşen** | 65+ bileşen · 133 public tip |
| **Mimari** | Atomic Design — Atoms · Molecules · Organisms |
| **Kod tabanı** | ~15.000 satır Swift · 136 dosya |
| **3. parti bağımlılık (çekirdek)** | **0** (yalnızca native SwiftUI) |
| **Tema** | 6 hazır tema (default/ocean/sunset × light/dark) |
| **Renk token'ı** | 128 semantik token + 50–900 renk merdivenleri |
| **Erişilebilirlik** | Dynamic Type + Reduce Motion + accessibility id'leri |
| **Lokalizasyon** | String Catalog — İngilizce varsayılan + Türkçe |
| **Test** | 55 test fonksiyonu · 11 test dosyası |
| **Dokümantasyon** | DocC kataloğu + 9 tasarım/analiz dökümanı |
| **Platform** | iOS 17+ · macOS 14+ · Swift 6.2 |

---

## 3. Neden etkileyici? (Farklılaştırıcılar)

**🎨 Token-first mimari (ADR-0001)**
Hiçbir bileşen rengi/spacing'i/radius'u hard-code etmez — hepsi aktif `Theme`'den çözülür.
Token'lar Figma'dan üretilir, JSON olarak runtime'da yüklenir. Bu, "tasarım sistemi"ni
slayttan koda taşıyan asıl şey.

**🔄 Runtime'da canlı tema değişimi**
`Theme.shared.loadTheme(named: "oceanTheme")` — tek satır, uygulama yeniden derlenmeden döner.
Dahası: **canlı tema konfigüratörü** var; rastgele bir accent rengi verince tüm 50–900
paleti anında yeniden üretiyor (Python `gen_tokens.py` mantığının Swift portu).

**📦 Sıfır bağımlılık + opsiyonel eklenti**
Çekirdek kütüphane tamamen native. Lottie animasyonu isteyen ayrı bir add-on target'tan alır;
istemeyen indirmez bile. Bağımlılık zincirini temiz tutan bilinçli bir karar.

**♿ Kurumsal hijyen built-in**
Erişilebilirlik (Dynamic Type ölçeklemesi, Reduce Motion kapıları, accessibility id'leri),
lokalizasyon (String Catalog) ve form doğrulama (`FormValidator`) çekirdeğe gömülü —
her projede yeniden çözülmesi gereken işler değil.

**🏷️ Marka-bağımsız**
Bilinçli olarak hiçbir marka adı içermez; her ürüne/markaya genel olarak uygulanabilir.

---

## 4. Mimari (nasıl kurgulandı)

```
Figma tasarım sistemi
        │  (token'lar)
        ▼
Resources/*.json  ──►  Theme (ObservableObject)  ──►  Bileşenler
  renk · radius          @ThemeContext                Atoms → Molecules → Organisms
  spacing                runtime yükleme              (rengi/spacing'i Theme'den çözer)
```

- **Atoms** (26 dosya): Icon, Badge, Chip, Avatar, Divider, Kbd…
- **Molecules** (38 dosya): Buttons, Checkbox, TextInput, Select, OTPInput, ListRow…
- **Organisms** (44 dosya): Card, Carousel, DataTable, CalendarView, NavigationBar, Hero, Pagination…

Token grupları: Renk/Radius/Spacing → JSON (temaya göre değişir) · Typography/Shadows → kod (yapısal, sabit).

---

## 5. Kanıt: çalışan Demo uygulaması

Kütüphaneyi yerel SPM referansı olarak bağlayan tam bir SwiftUI demo app mevcut:

- **Galeri / Katalog** — registry tabanlı; her bileşen, ayarlanabilir "knob"larla canlı önizlenir.
- **Gerçek akış örneği** — uçtan uca bir **otel rezervasyon akışı** (Arama → Sonuçlar → Detay →
  Ödeme → Favoriler) tamamen bu bileşenlerden kurulmuş. "Oyuncak demo" değil, gerçek bir ürün senaryosu.
- **Tema galerisi + canlı konfigüratör** — temalar arası geçiş ve özel accent üretimi anında görülüyor.

> Bir lead'e en hızlı etki: demo'yu açıp temayı canlı değiştirmek ve aynı otel akışının
> anında başka bir markaya bürünmesini göstermek.

---

## 6. Mühendislik titizliği

- **Swift 6 strict concurrency** uyumlu (Sendable temizliği yapılmış).
- **Tasarım disiplini:** Ant Design'ın 10 prensibi somut kurallara çevrilmiş ve kütüphane bunlara
  karşı denetlenmiş (`docs/design-principles.md`); Ant ve daisyUI'ye karşı boşluk analizleri yapılmış.
- **DocC** dokümantasyon kataloğu (Theming / Accessibility / FormValidation makaleleri).
- **Test:** tema bütünlüğü, token üretici sağlamlığı, validator edge-case'leri ve render smoke testleri.

---

## 7. İş değeri (lead'in duymak istediği)

| Etki | Sonuç |
|---|---|
| **Hız** | Yeni ekran/proje günler değil saatler — bileşenler hazır. |
| **Tutarlılık** | Tek token kaynağı → marka boyunca piksel tutarlılığı. |
| **Marka çevikliği** | Yeniden markalaşma kod değil konfig işi (saatler, haftalar değil). |
| **Bakım maliyeti** | Erişilebilirlik/lokalizasyon/doğrulama bir kez çözülmüş, her projede yeniden değil. |
| **Risk** | Sıfır 3. parti bağımlılık (çekirdek) → daha az güvenlik/sürüm riski. |

---

## 8. Sırada ne var? (yol haritası)

- Press/aktif feedback'in tüm tıklanabilir yüzeylere yayılması (ListRow, Chip, Card).
- Navigasyon/accordion geçişlerinde `Motion` token tutarlılığı denetimi.
- Select için loading/grouped/custom-option gibi opsiyonel zenginleştirmeler.
- Daha geniş test kapsamı ve snapshot testleri.

---

## 9. 60 saniyelik anlatım metni (lead konuşması için)

> "Her ekip aynı butonu, input'u, kartı yeniden yazıyordu. Biz bunu Figma token'larından
> beslenen tek bir SwiftUI kütüphanesine indirgedik. 65'in üzerinde üretime hazır bileşen var,
> hepsi token-tabanlı — yani bileşen koduna dokunmadan, tek satırla tüm uygulamayı başka bir
> temaya çevirebiliyoruz. Çekirdekte sıfır 3. parti bağımlılık, erişilebilirlik ve lokalizasyon
> gömülü. Çalışan bir demo'muz var: gerçek bir otel rezervasyon akışını bu bileşenlerle kurduk
> ve temayı canlı değiştirip aynı akışın anında başka bir markaya büründüğünü gösterebiliyorum.
> Sonuç: yeni proje açılışı saatlere iner, marka değişimi konfig işine döner, bakım borcu düşer."

---

*Kaynak: `ThemeKit` SPM paketi · `Demo/` SwiftUI uygulaması · `docs/` tasarım & analiz dökümanları.*
