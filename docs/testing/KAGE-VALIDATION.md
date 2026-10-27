# Kage 0.2.0 validation / doğrulama

Date / Tarih: 2026-10-27. Local machine / Yerel makine: Apple Silicon, macOS 27.0.1.

## English

Kage is an independent macOS fork of Nashi. Version 0.2.0 removes the added Security Center, fingerprint comparison, inspection reports and inspection CLI/engine. It keeps the black/red interface, original conversion/editing tools and scoped bug fixes. Original Nashi metadata and redaction tools remain available. No new file-scanning product is included.

### Automated results

| Check | Result |
| --- | --- |
| Release app build | Passed; bundled tools, ad-hoc signature |
| Swift regression suites | 295 discovered; 293 passed, 2 opt-in live network tests skipped; 0 failures |
| Native UI matrix | 40 captures: 10 scenes × 2 themes × EN/TR |
| UI validators | 19 guardrails, 30 accessible range checks, 11 artwork checks; parser/output protection passed |
| Packaged app smoke | 18 passed, including real image/PDF/Office/archive/audio operations, opaque redaction and signature verification after conversion |
| Packaged audio | 41 passed across WAV, MP3, M4A, FLAC, OGG/Vorbis, Opus, AIFF, WMA |
| Removed feature | Source/UI references and binary symbols absent; removed CLI command fails rather than launching a second app |

Audio fixtures are generated six-second stereo signals at 48 kHz, with distinct left/right frequencies (440/880 Hz). Checks cover duration, sample rate, stereo identity, non-silence, finite/unclipped decoded samples, seven conversion round trips back to WAV, a two-second trim, left-channel mute, mono mix, loudness/true peak, metadata removal, batch output uniqueness, original preservation and malformed-file failure without partial output. These are signal/file checks, not a listening test of a physical speaker or headphones.

### Native interaction evidence

- WAV and MP3 playback advanced with Space; play/pause state and playhead were observed.
- Home/arrow keys and I/O selected 1–3 seconds; Shift+Space played the selected range; Command+S exported a separate stereo WAV lasting exactly 2.000 seconds. Command+W closed the tool window.
- An OGG file converted to a real WAV through the native quick action. Editing tools in the upstream catalog apply to MP3/M4A/WAV/FLAC; convert the other four formats to WAV before editing.
- Control+Shift+D opened the download window. Copying a valid HTTP media URL, clearing the field, closing and reopening with the shortcut restored the URL automatically and inspected it. A generated WAV served only on loopback downloaded byte-for-byte unchanged. Ordinary text/checksums do not prefill the URL field.
- The user physically confirmed the global shortcut opens the window while Finder is foreground. Automated native key delivery alone did not establish background/global dispatch. Finder drag with physical modifiers has not been independently retested for this release.
- Previous daily checks established Command+F search focus, text-field paste, Command+O, wheel navigation, Library preview/reuse, video trim/playback, Command+W, quit/reopen and preference persistence; the UI suite repeats search-focus regressions for the current workspace/library.

### Reproduce and limits

Run the commands in the [English README](../../README.md#verify) with fresh output directories. The source workflow repeats the full regression, packaged UI/smoke and audio checks on GitHub. Check the actual run attached to the release commit; local success does not establish a future CI result.

The release targets Apple Silicon, macOS 13+. Local runtime results cover the machine above, not every supported OS or device. Live Instagram/YouTube/CDN availability is not guaranteed. This is an ad-hoc signed build without Apple Developer ID notarization; automatic updates and launch-at-login are unavailable. Keep macOS security protections enabled.

## Türkçe

Kage, Nashi’nin bağımsız macOS fork’udur. 0.2.0 sürümünde eklenen Güvenlik Merkezi, parmak izi karşılaştırması, inceleme raporları ve inceleme komutu/motoru kaldırıldı. Siyah/kırmızı tema, özgün dönüştürme/düzenleme araçları ve kapsamı belirli hata düzeltmeleri korundu. Nashi’nin özgün metadata ve sansür araçları yerinde duruyor; ek dosya tarama ürünü sunulmuyor.

### Otomatik sonuçlar

| Kontrol | Sonuç |
| --- | --- |
| Yayın uygulaması derlemesi | Geçti; araçlar pakette, ad-hoc imzalı |
| Swift regresyon testleri | 295 test; 293 geçti, isteğe bağlı 2 canlı ağ testi atlandı; 0 hata |
| Yerel arayüz matrisi | 10 ekran × 2 tema × TR/EN = 40 görüntü |
| Arayüz doğrulamaları | 19 koruma, 30 erişilebilir aralık, 11 dosya görseli kontrolü; komut/çıktı korumaları geçti |
| Paketli uygulama | Gerçek görsel/PDF/Office/arşiv/ses işlemleri, opak sansür ve işlem sonrası imza dahil 18 kontrol geçti |
| Paketli ses | WAV, MP3, M4A, FLAC, OGG/Vorbis, Opus, AIFF, WMA üzerinde 41 kontrol geçti |
| Kaldırılan özellik | Kaynak/arayüz referansları ve ikili semboller yok; kaldırılan komut ikinci uygulama açmak yerine hata veriyor |

Ses testlerinde 48 kHz, altı saniyelik sentetik stereo kullanılır; sol/sağ kanallar 440/880 Hz ile ayrılır. Süre, örnekleme, kanal kimliği, sessizleşme, sonlu/taşmayan örnekler, yedi biçimden WAV’a geri dönüş, iki saniye kırpma, yalnız sol kanalı susturma, mono karışım, ses yüksekliği/tepe sınırı, metadata kaldırma, toplu dosya adları, kaynakların korunması ve bozuk dosyada yarım çıktı bırakmama doğrulanır. Fiziksel hoparlör/kulaklıkla dinleme testi yapılmış sayılmaz.

### Gerçek uygulama kullanımı

- WAV ve MP3’te Space ile oynatma ilerledi; oynat/duraklat durumu ve zaman göstergesi gözlendi.
- Home/oklar ve I/O ile 1–3 saniye seçildi; Shift+Space bu aralığı oynattı. Command+S tam 2,000 saniyelik ayrı stereo WAV üretti; Command+W araç penceresini kapattı.
- OGG, arayüzdeki hızlı eylemle gerçek WAV’a dönüştü. Özgün katalogdaki düzenleme araçları MP3/M4A/WAV/FLAC için sunuluyor; diğer dört biçimi önce WAV’a çevir.
- Control+Shift+D indirme penceresini açtı. Geçerli HTTP medya URL’si kopyalandı, alan temizlendi, pencere kapatılıp kısayolla yeniden açıldığında URL otomatik doldu ve kontrol edildi. Yalnız yerel makinede sunulan sentetik WAV birebir aynı indirildi. Normal metin ve özet değerleri URL alanını doldurmaz.
- Kullanıcı Finder öndeyken fiziksel klavyede genel kısayolun pencereyi açtığını doğruladı. Otomatik tuş gönderimi arka plandaki genel kısayolu tek başına kanıtlamadı. Finder’da fiziksel tuşla sürükleme bu sürüm için ayrıca tekrar denenmedi.
- Önceki günlük kontrollerde Command+F arama odağı, metin alanında yapıştırma, Command+O, çark gezinmesi, Kitaplık önizleme/yeniden kullanma, video kırpma/oynatma, Command+W, çıkıp açılma ve tercihlerin korunması doğrulandı. Güncel arayüz testleri çalışma alanı/Kitaplık arama odağı regresyonunu tekrarlar.

### Tekrar çalıştırma ve sınırlar

[Türkçe README](../../README.tr.md#doğrula) komutlarını boş çıktı klasörleriyle çalıştır. GitHub kaynak iş akışı tüm regresyon, paketli arayüz/işlem ve ses kontrollerini tekrarlar. Yayın kaydının bağlı olduğu gerçek çalışmaya bak; yerel başarı gelecekteki CI sonucunu kanıtlamaz.

Hedef Apple Silicon/macOS 13+; yerel sonuçlar yukarıdaki makineyi kapsar, tüm işletim sistemi ve donanımları değil. Canlı Instagram/YouTube/CDN erişimi garanti edilmez. Paket Apple Developer ID ile notarize edilmemiş ad-hoc imzalıdır; otomatik güncelleme ve oturum açılışında başlatma kullanılamaz. macOS korumalarını açık tut.
