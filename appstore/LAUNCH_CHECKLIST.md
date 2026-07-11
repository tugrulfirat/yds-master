# Yayın Kontrol Listesi

## SENİN yapman gerekenler (kod dışı — Claude yapamaz)

1. **Apple Developer Program kaydı** — developer.apple.com/programs,
   $99/yıl. Kimlik doğrulama genellikle 24–48 saat sürer. → HEMEN BAŞLAT.
2. **App Store Connect'te Paid Apps sözleşmesi** — Agreements, Tax, and
   Banking: banka hesabı (IBAN) + vergi formları. Abonelik satmak için
   ZORUNLU; onayı günler sürebilir. → Kayıt biter bitmez doldur.
3. **App Store Connect'te uygulama oluştur** — Bundle ID:
   `com.tugrulfirat.ydsmaster`, ad: "YDS Master: Kelime Oyunları".
4. **Abonelik ürünlerini oluştur** — metadata_tr.md'deki tabloya göre
   3 ürün, "Premium" grubu. Product ID'ler koddakiyle AYNEN eşleşmeli.
5. **Gizlilik politikası yayınla** — `privacy_policy_tr.html` dosyasını
   herhangi bir yerde barındır (GitHub Pages en kolayı: yeni repo →
   Settings → Pages). Sonra:
   - PaywallView.swift içindeki `privacyPolicyURL`'i gerçek adresle değiştir
   - metadata_tr.md içindeki <PRIVACY_URL> alanını doldur
   - App Store Connect'teki Privacy Policy URL alanına gir
6. **App Privacy anketi** (App Store Connect): "Data Not Collected" —
   uygulama hiçbir veri toplamıyor (tamamen çevrimdışı, analytics yok).
7. **Export compliance**: yalnızca muaf şifreleme (HTTPS bile yok) —
   "None of the algorithms mentioned" / exempt seç.
8. **Xcode'dan Archive + Upload** — Product → Archive → Distribute App →
   App Store Connect. (İlk arşivde otomatik imzalama team'i paid team'e
   geçirmeyi ister — kayıt tamamlanınca Xcode'da Apple ID'n güncellenir.)
9. **Ekran görüntülerini yükle** — appstore/screenshots/ (1320×2868,
   6.9" iPhone). Sıra: 1_ana_ekran → 6_word_circuit.
10. **İncelemeye gönder.** İlk inceleme tipik olarak 24–48 saat.

## Karar bekleyen konu (ÖNEMLİ)

- **Örnek cümleler**: words.json içindeki `exampleSentenceEN` alanları
  geçmiş sınav PDF'lerinden birebir alınmış cümleler içeriyor. UI'da
  gösterilmiyor ama pakette dağıtılıyor. Ticari yayın öncesi bu alanların
  boşaltılması önerilir (tek komut, geri alınabilir). ÖSYM içeriğinin
  ticari kullanım hakları belirsiz.

## Kodda hazır olanlar

- [x] StoreKit 2 abonelik altyapısı (PremiumStore.swift)
- [x] 500 ücretsiz kelime / gerisi kilitli (WordStore.playableWords)
- [x] Türkçe paywall: 3 plan, geri yükleme, yasal linkler (PaywallView.swift)
- [x] Kelime Bankası'nda kilitli kelime görünümü (bulanık anlam + kilit)
- [x] Ana ekranda "Premium'a Geç" girişi
- [x] Yerel test için YDSMaster.storekit config
      (Xcode: scheme → Run → Options → StoreKit Configuration seç)
- [x] 6 adet 1320×2868 Türkçe ekran görüntüsü (appstore/screenshots/)
- [x] Türkçe mağaza metinleri (metadata_tr.md)
- [x] Gizlilik manifestosu (PrivacyInfo.xcprivacy), opak ikon, DEBUG-gated
      debug kancaları

## Gerçekçi zaman çizelgesi

| Gün | Ne olur |
|---|---|
| Bu gece | Developer kaydını başlat, banka/vergi formlarını doldur |
| +1–2 gün | Kayıt onayı → App Store Connect kurulumu (uygulama, abonelikler, metadata, ekran görüntüleri) |
| +2–3 gün | Archive + upload + incelemeye gönderim |
| +3–7 gün | İnceleme sonucu → yayında 🎉 |
