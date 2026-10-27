# Kage · macOS

[English](README.md) · [Türkçe](README.tr.md)

**Kage, Orkun Işıtmak ve katkıda bulunanların geliştirdiği [Nashi](https://github.com/orkunisitmak/nashi-app) projesinin bağımsız macOS fork’udur.** Nashi’nin dönüştürme ve düzenleme araçlarını korur; siyah/kırmızı, terminal esintili bir arayüz ve belgelenmiş hata düzeltmeleri sunar. Kage’ye özgü değişiklikler Basri Akkaya’ya aittir. Resmî Nashi yayını değildir.

![Kage çalışma alanı](docs/assets/kage/workspace-dark-tr.png)

## Neler yapar?

- Görsel, PDF, ses, video, belge ve arşivler için 45 girdi biçimi ve 27 araç.
- MP3, M4A, WAV, FLAC, OGG/Vorbis, Opus, AIFF ve WMA arasında ses dönüşümü; kırpma, normalleştirme, kanal kontrolleri ve metadata kopyaları.
- Dosya önizlemesi, aranabilir geçmiş, toplu dışa aktarma ve özgün sürükle–çark akışı.
- Kage simgesi, siyah/kırmızı çalışma alanı, Türkçe/İngilizce ve açık/koyu arayüz. İlk tercih Türkçe/koyudur; Ayarlar’dan değiştirebilirsin.
- Ayrı uygulama kimliği ve tercihler. Bu bağımsız sürümde Nashi’nin otomatik güncelleme kanalı kullanılmaz.

Çalışma alanı dönüştürme ve düzenlemeye odaklanır. Ek dosya tarama paneli, parmak izi karşılaştırma ekranı veya inceleme raporu özelliği içermez. Depodaki Windows kaynakları upstream referansıdır; **Kage yayınları Apple Silicon / macOS 13+ içindir.**

## Kurulum

1. [Kage yayınları](https://github.com/basriakkaya/nashi-app/releases) sayfasından macOS ZIP’ini indir.
2. ZIP’i açıp **Kage.app** dosyasını **Uygulamalar** klasörüne sürükle.
3. Kage’yi aç; dosyanı seç veya bırak.

Medya, belge ve metadata araçları pakete dahildir; sistem geneline ek kurulum gerekmez. Bu sürüm **yerel/ad-hoc imzalıdır; Apple Developer ID ile notarize edilmiş bir yayın değildir** ve macOS indirilen kopyayı engelleyebilir. Sistem korumalarını açık tut. Bu yerel sürümde otomatik güncelleme ve oturum açılışında başlatma kullanılamaz. İsteğe bağlı pencere düzenleme başlangıçta kapalıdır; açılırsa ayrıca macOS izni gerekir.

## Günlük kısayollar

| Kısayol | İşlev |
| --- | --- |
| ⌘1 / ⌘2 | Çalışma Alanı / Kitaplık |
| ⌘O | Dosya seç |
| ⌘F | Kitaplığı aç ve aramayı odakla |
| ⌘V | Kopyalanmış dosya, metin, görsel veya desteklenen bağlantıyı al; metin alanında normal yapıştır |
| Çalışma alanında Enter / ⌘Enter | Seçili dosyaların araçlarını aç |
| Çarkta oklar, Enter, Esc | Seç, uygula, iptal et |
| Kitaplıkta ↑/↓, Space, Enter | Sonuç seç, önizle, yeniden kullan |
| ⌘, / ⌘W / ⌘Q | Ayarlar / pencereyi kapat / çık |
| ⌃⇧D | Web indirme penceresini aç; panodaki geçerli HTTP(S) medya bağlantısını doldur |
| Sürüklerken ⇧ / ⌘ / ⌃ | Dönüştürme / araçlar / dosya işlemleri; Ayarlar’dan değiştirilebilir |
| Ses/video düzenleyicide Space | Oynat/duraklat |
| Düzenleyicide ←/→, ⇧←/→ | Bir saniye / hassas adım (videoda bir kare, seste 0,1 sn) |
| Zaman kırpmada I / O / ⇧Space | Başlangıç / bitiş işaretle / seçili aralığı oynat |
| ⌘S | Yeni çıktı kopyasını kaydet |

**Bağlantının otomatik dolması:** önce gerçek medya/paylaşım URL’sini kopyala, sonra Control+Shift+D’ye bas. Yerel dosya, özet değeri veya sıradan metin web bağlantısı değildir; bu durumda alan otomatik dolmaz. Yalnızca herkese açık medya desteklenir; giriş gerektiren ve korumalı içerik kullanılamayabilir. Web indirmeleri seçtiğin siteye bağlanır; dönüştürme ve düzenlemeler yerelde çalışır.

Yerel düzenleme araçları MP3, M4A, WAV ve FLAC için sunulur. OGG, Opus, AIFF veya WMA dosyasını önce WAV’a dönüştürüp çıkan dosyayı düzenleme için aç. Ses dosyanı seçip bir çıktı biçimine veya ses aracına geç. Kaydetmeden önce aralığı ve kanalları kontrol et. Çıktılar yeni dosyalardır; kaynak korunur. Kayıplı biçimler ses sinyalini değiştirir ve her dönüşümün dosyayı küçültmesi beklenmemelidir.

## Fork’ta korunan düzeltmeler

- Düz görsel/video sansürü opak kalır ve kesirli piksel seçimlerini kapsar.
- Arşiv bağlantı hedefleri dosyalar oluşturulmadan önce doğrulanır.
- Belge dönüştürücü imzalı paket içine Python önbelleği yazmaz; CSV/TSV sayıları tutarlı yerelle çıkar ve PDF sunum görsellerinin renkleri korunur.
- ⌘F yeni açılan arama alanını doğru odaklar; ⌘W kenarlıksız araç pencerelerinde çalışır.

Bunlar kapsamı belli düzeltme ve testlerdir; her olası tehdit veya girdi için garanti değildir. [Doğrulama ve ses kapsamı](docs/testing/KAGE-VALIDATION.md) belgesine bak.

## Kaynaktan derle

Apple Silicon macOS üzerinde Swift 6 içeren Xcode ve Python 3.11+ gerekir.

```sh
python3 scripts/setup-kage-tools.py
zsh scripts/build-kage.sh release
open build/Kage.app
```

Varsayılan çıktı `build/Kage.app`; farklı hedef için `KAGE_APP_OUTPUT` kullanılır. Araç indirmeleri sabitlenmiş özetlerle doğrulanır. Bileşen lisansları pakette korunur.

## Doğrula

```sh
swift test
python3 scripts/test-native-ui.py --app build/Kage.app/Contents/MacOS/Kage --output work/native-ui
build/Kage.app/Contents/MacOS/Kage --kage-smoke work/packaged-smoke
python3 scripts/test-kage-audio.py --app build/Kage.app --output work/audio-qa
```

Yeni ve boş çıktı klasörleri kullan. Arayüz matrisi 40 görünüm/tema/dil birleşimini kapsar. Ses kontrolleri sentetik sinyaller üretip süre, kanal, örnekleme hızı, sessizleşmeme, kanal kimliği, geri dönüşümler ve gerçek araç çıktılarını doğrular. GitHub’da tüm çekirdek/güncelleme testleri, paket kontrolleri ve ses doğrulaması çalışır. Canlı Instagram/YouTube CDN testleri isteğe bağlıdır; fiziksel sürükleme/tuş davranışı arayüz görselleri ve motor testlerinden ayrı değerlendirilir.

## Kaynak ve lisans

Upstream: [orkunisitmak/nashi-app](https://github.com/orkunisitmak/nashi-app). Özgün telif hakkı ve [MIT lisansı](LICENSE) korunur. [Kage bildirimi](Resources/KAGE-NOTICE.txt), [üçüncü taraf bildirimleri](Resources/THIRD-PARTY-NOTICES.txt) ve `Resources/licenses/` dizinine bak. Kage, resmî Nashi yayını ve Tangerine/LEAP STUDIO’dan bağımsızdır. `Nashi*` modül adları upstream değişikliklerini izlenebilir tutmak için korunmuştur.
