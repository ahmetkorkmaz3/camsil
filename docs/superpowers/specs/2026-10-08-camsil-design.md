# Camsil — Ekran Silme Uygulaması: Tasarım Belgesi

- **Tarih:** 2026-10-08
- **Durum:** İncelemede
- **Yazar:** Ahmet Korkmaz

## 1. Amaç

Camsil, bilgisayar ekranını bir evin kirli penceresi gibi gösteren bir macOS uygulamasıdır. Kullanıcı bir cam silme şişesi ile ekrana sıkar ve bir bez ile ekranı siler.

- Proje kişisel ve eğlence amaçlıdır.
- Ana hedef, X'te paylaşılacak kısa bir videodur.
- İlham kaynağı: terkelg'in "masaüstü halısı" uygulaması. O uygulama gerçek masaüstü simgelerinin üstünde çalışan bir kumaş simülasyonudur. Camsil aynı yaklaşımı izler: gerçek ekranın üstünde, gerçek zamanlı ve fiziksel bir his.

### Başarı ölçütleri

1. Uygulama açılınca gerçek ekran, kirli bir camın arkasındaymış gibi görünür.
2. Kullanıcı şişe ve bez ile ekranı temizler. Temizlik gerçek cam silme gibi hissettirir.
3. Retina ekranda animasyon 120 Hz akıcı çalışır.
4. Kullanıcı hiçbir durumda ekranda kilitli kalmaz.
5. Ekran temiz olunca bir bitiş efekti çalışır ve uygulama kapanır.

## 2. Kapsam

### Kapsam içinde

- macOS 14 (Sonoma) ve sonrası.
- Yalnızca ana ekran.
- İki araç: şişe ve bez.
- Üç kir türü: toz tabakası, kurumuş su lekeleri, parmak izleri.
- Ses efektleri.
- GitHub üzerinden imzalı ve notarize bir `.dmg` dağıtımı.

### Kapsam dışında (ilk sürüm)

- Birden fazla monitör.
- Çekpas (silecek) aracı.
- Akıntı izleri.
- Zamanla biriken toz ve arka planda çalışma.
- App Store dağıtımı.
- Ekran Kaydı izni olmadan çalışan sade mod.

## 3. Kararlar

| Konu | Karar |
|---|---|
| Teknoloji | Swift + AppKit + Metal |
| Araçlar | Şişe sıkar, bez siler |
| Kuru silme | Kiri biraz azaltır, dağıtır ve çizgi bırakır |
| Kirlenme | Açılışta hemen |
| Fare | Temizlik bitene kadar bütün tıklamalar uygulamaya gider |
| Ekran Kaydı izni | Gerekli. Kırılma ve bulanıklık için kullanılır |
| Ekranlar | Yalnızca ana ekran |
| Ses | Var |

Seçilmeyen yaklaşımlar:

- **SpriteKit:** Retina çözünürlükte maske boyama ve kırılma efekti zor ve yavaş.
- **Tauri veya Electron + WebGL:** Şeffaf üst pencere ve ScreenCaptureKit entegrasyonu zor. Uygulama büyük olur.

## 4. Mimari

### 4.1 Bileşenler

| Bileşen | Görevi |
|---|---|
| `AppController` | Uygulamayı başlatır. Ekran Kaydı iznini kontrol eder. `Esc`, `Cmd+Q` ve "temiz" durumunu dinler. Uygulamayı kapatır. |
| `OverlayWindow` | Ana ekranı kaplayan şeffaf ve çerçevesiz pencere. Seviyesi `.screenSaver`. `collectionBehavior` değeri `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`. Bütün fare olaylarını alır. |
| `ScreenCapture` | ScreenCaptureKit ile ana ekranı 60 fps okur. `SCContentFilter` kendi pencerelerimizi görüntüden çıkarır. Görüntüyü bir Metal dokusuna verir. |
| `Simulation` | Camın durumunu GPU dokularında tutar: kir maskesi, ıslaklık haritası, damla haritası. Damla listesini CPU üzerinde tutar. |
| `Tools` | Şişe ve bez. Fare olaylarını darbelere (stamp) çevirir ve `Simulation` içine verir. |
| `Renderer` | Her karede ekran görüntüsünü, kiri, ıslaklığı ve damlaları tek bir shader ile birleştirir. Araç görselini imlecin yerine çizer. |
| `Audio` | AVAudioEngine ile sesleri çalar. |
| `Progress` | Saniyede 2 kez kir maskesini GPU üzerinde toplar ve "% temiz" değerini verir. |

Her bileşen tek bir işi yapar ve küçük bir arayüz verir. Silme kuralları ve damla fiziği, GPU kodundan ayrı saf Swift fonksiyonları olarak da yazılır. Bu fonksiyonlar birim testlerinde referans olarak kullanılır.

### 4.2 Veri akışı (bir kare)

1. `ScreenCapture`, arkadaki ekranın son görüntüsünü verir.
2. `Tools`, son fare olaylarını darbelere çevirir.
3. `Simulation` darbeleri uygular. Şişe ıslaklık ve damla ekler. Bez ıslaklığı, damlaları ve kiri azaltır. Islaklık zamanla kurur. Büyük damlalar aşağı akar.
4. `Renderer` sonucu çizer. Kirli yerde ekran bulanık ve gri görünür. Damlalar ekranı kırar ve ışık parlaması gösterir.
5. `Progress` %95 değerini görünce `AppController` bitiş efektini başlatır.

### 4.3 GPU dokuları

Simülasyon dokuları ekranın yarı çözünürlüğünde çalışır.

| Doku | Kanallar | İçerik |
|---|---|---|
| `dirtMask` | R: toz, G: su lekesi, B: parmak izi | 0 = temiz, 1 = tam kirli |
| `wetMap` | R | 0 = kuru, 1 = tam ıslak |
| `dropNormals` | RG: normal, B: kalınlık | Damlaların kırılma bilgisi. Her karede damla listesinden çizilir. |
| `screenBlur` | RGBA | Ekran görüntüsünün bulanık kopyası (mipmap). Kirli yerlerde kullanılır. |

### 4.4 Diğer teknik notlar

- Sistem imleci gizlenir (`NSCursor.hide`). Araç görseli imlecin yerine çizilir.
- Uygulama Dock'ta görünmez (`LSUIElement`).
- Uygulama açılınca kendini öne alır (`NSApp.activate`). Pencere klavye odağını alır. Bu yüzden `Esc` her zaman çalışır.

## 5. Araçlar ve etkileşim

### 5.1 Araç değiştirme

- **Sağ tık** veya **Space** aracı değiştirir: şişe ↔ bez.
- **1** tuşu şişeyi, **2** tuşu bezi seçer.
- Uygulama, şişe seçili olarak başlar.
- Açılışta ekranın altında 3 saniye bir ipucu görünür: "Sağ tık: araç değiştir · Esc: çık".

### 5.2 Şişe

- Şişenin görseli imlecin sağ altında durur. Şişenin ağzı imlecin ucunu gösterir.
- Bir tık bir sıkış yapar. Tuş basılı kalırsa şişe saniyede 4 kez sıkar.
- Her sıkışta şişe hafifçe geri teper ve sıkışır (squash). "Pssş" sesi çalar.
- Bir sıkış, imleç çevresinde yaklaşık 180 pt yarıçaplı bir sprey bulutu oluşturur.
- Bulut yüzlerce küçük damla ve birkaç büyük damla bırakır. Damlalar merkezde daha yoğundur.
- Sıkılan yer ıslak olur (`wetMap` artar).

### 5.3 Damlalar ve ıslaklık

- Küçük damlalar yerinde kalır ve yavaşça kurur.
- Yakın damlalar birleşir. Bir boyut eşiğini geçen damla aşağı akar ve arkasında ıslak bir iz bırakır.
- Silinmeyen ıslak bir yer yaklaşık 8 saniyede kurur. Kuruyan yerde kir değişmez.

### 5.4 Bez

- Bezin görseli yeşil bir mikrofiber bezdir. Bez, hareket yönüne göre hafifçe döner.
- Bez yalnızca sol tuş basılıyken siler. Silme yarıçapı yaklaşık 70 pt.
- Bez, geçtiği yerdeki damlaları ve ıslaklığı alır.
- Silerken bezin hızına bağlı bir gıcırtı sesi çalar.

### 5.5 Silme kuralları

Bir geçiş, bezin bir noktanın üstünden bir kez geçmesidir. Aşağıdaki değerler başlangıç değerleridir. Prototipte ayarlanır.

| Kir türü | Islak silme (bir geçiş) | Kuru silme (bir geçiş) |
|---|---|---|
| Toz tabakası | %70 azalır | %10 azalır. Kalan toz bezin yönünde sürüklenir ve çizgi bırakır. |
| Su lekeleri | %50 azalır | Değişmez |
| Parmak izleri | %30 azalır | Lekelenir ve bezin yönünde büyür |

Bir nokta, `wetMap` değeri 0,3'ten büyükse ıslak sayılır.

### 5.6 Başlangıç ve bitiş

- **Başlangıç:** Kir 1,5 saniyede ekranın üstüne yavaşça gelir.
- **Gösterge:** Ekranın köşesinde küçük bir "% temiz" göstergesi durur.
- **Bitiş:** Ekran %95 temiz olunca kalan kir 0,5 saniyede kaybolur. Camın üstünden çapraz bir ışık parlaması geçer ve "pırıl" sesi çalar. Pencere 1 saniyede kaybolur ve uygulama kapanır.

## 6. Görseller

| Öğe | Kaynak |
|---|---|
| Şişe | Kullanıcının verdiği Camsil şişe görseli. Arka planı şeffaf bir PNG'ye çevrilir. |
| Bez | Shader ile kodla üretilen yeşil mikrofiber doku. |
| Toz tabakası | Kodla üretilir (fbm gürültü). |
| Su lekeleri | Kodla üretilir. Kenarı koyu, ortası açık yuvarlak lekeler. |
| Parmak izleri | Kodla üretilir. Ekranın 4–6 rastgele yerinde gürültülü elips çizgiler. |

- Her açılışta kir yeni bir rastgele tohum (seed) ile üretilir.
- Kullanıcının örnek cam fotoğrafları yalnızca görsel referanstır. Uygulamanın içine girmez.
- Şişe görseli tescilli bir markaya aittir. Proje kişisel ve ticari olmayan bir projedir. Uygulama herkese dağıtılmadan önce bu konu tekrar değerlendirilir.

## 7. Sesler

| Ses | Davranış |
|---|---|
| Sprey | Her sıkışta bir kez çalar. Ton her seferinde biraz değişir. |
| Gıcırtı | Bez hareket ederken döngüde çalar. Sesin yüksekliği ve tonu bezin hızına göre değişir. |
| Bitiş | "Pırıl" sesi, bitişte bir kez çalar. |

- Sesler CC0 (telifsiz) kaynaklardan gelir, örneğin freesound.org.
- Kaynakların listesi `CREDITS.md` dosyasında tutulur.

## 8. Hata durumları

| Durum | Davranış |
|---|---|
| Ekran Kaydı izni yok | Küçük bir pencere izni açıklar. Bir düğme Sistem Ayarları'nı açar. Uygulama kapanır. Kullanıcı izni verip uygulamayı tekrar açar. |
| Görüntü akışı durur (uyku, ekran değişimi) | Son görüntü ekranda kalır. Akış yeniden başlar. Ana ekran değişirse uygulama kapanır. |
| Kullanıcı ekranda kilitli kalır | Üç çıkış yolu var: `Esc`, `Cmd+Q`, ve 2 dakika hiç fare veya tuş olayı olmazsa otomatik kapanma. |
| Metal cihazı yok veya shader derlenmez | Uygulama bir hata mesajı gösterir ve kapanır. Pencere hiç açılmaz. |

## 9. Test

1. **Birim testleri (XCTest):** Araç değiştirme durumu, silme kurallarının matematiği, damla fiziği, kuruma süresi ve "%95 temiz" eşiği. Bu mantık saf Swift fonksiyonları olarak test edilir.
2. **Görüntü testi:** Sabit bir test ekran görüntüsü ile `Renderer` bir kare çizer. Testler sonucun özelliklerini kontrol eder: temiz cam ekranı aynen gösterir, toz kontrastı düşürür, pencere opaklığı 0 ise çıktı şeffaftır, parlama ekranı aydınlatır.
3. **Hata ayıklama görünümü:** Debug sürümünde `D` tuşu `dirtMask`, `wetMap` ve `dropNormals` dokularını ekranda gösterir.
4. **Elle test listesi:**
   - Retina ekranda 120 Hz akıcılık (Instruments ile ölçülür).
   - İzin olmadan ilk açılış ve izin akışı.
   - Her durumda `Esc` ve `Cmd+Q` ile çıkış.
   - 2 dakika hareketsizlik sonrası otomatik kapanma.
   - İkinci monitörün temiz kalması.

## 10. Proje yapısı

- Xcode projesi `XcodeGen` ile `project.yml` dosyasından üretilir.
- Klasörler:

```
Camsil/
  App/          AppController, Info.plist, giriş noktası
  Overlay/      OverlayWindow, olay yönetimi
  Capture/      ScreenCapture
  Simulation/   dokular, damla listesi, silme kuralları
  Tools/        şişe, bez, araç durumu
  Rendering/    Renderer, .metal shader dosyaları
  Audio/        Audio, ses dosyaları
  Resources/    şişe görseli, Assets
CamsilTests/    birim ve görüntü testleri
project.yml
CREDITS.md
```

## 11. Açık konular

- Silme kurallarındaki yüzdeler, damla eşikleri ve kuruma süresi prototipte ayarlanır.
- Şişe görselinin arka planı şeffaf bir PNG'ye çevrilmelidir. Kullanıcı bir PNG verir veya arka plan kodla temizlenir.
