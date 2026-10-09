# Sürüm çıkarma

## Bir kez: imza sertifikası

1. `scripts/make-signing-cert.sh` komutunu çalıştırın. Betik `~/Camsil-signing` klasörünü oluşturur.
2. Betiğin yazdığı adımları uygulayın: iki GitHub secret ekleyin ve `.p12` dosyasını parola yöneticisine kaydedin.
3. `~/Camsil-signing` klasörünü silin.

**Uyarı:** `.p12` dosyasını kaybederseniz yeni bir sertifika gerekir. Bu durumda her kullanıcı güncellemeden sonra Ekran Kaydı iznini bir kez yeniden verir.

## Bir kez: GitHub

1. Repo `ahmetkorkmaz3/camsil` adıyla GitHub üzerinde olmalı. Varsayılan dal `main` olmalı. `install.sh` ve `README.md` bu adları kullanır.
2. GitHub → Settings → Pages → Source alanında **GitHub Actions** seçin.

## Her sürüm

1. `CHANGELOG.md` dosyasında `## [Unreleased]` başlığını `## [X.Y.Z] - YYYY-MM-DD` yapın. Üstüne yeni ve boş bir `## [Unreleased]` başlığı ekleyin.
2. Commit edin ve `main` dalına push edin.
3. Etiketi oluşturun ve push edin:

   ```sh
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

4. GitHub → Actions → Release iş akışının bitmesini bekleyin (yaklaşık 10 dk).
5. Kurulum komutunu deneyin:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/ahmetkorkmaz3/camsil/main/install.sh | sh
   ```

6. `docs/manual-test.md` bölüm 5 adımlarını uygulayın.

İş akışı şu durumlarda durur: etiket `vX.Y.Z` biçiminde değil, CHANGELOG bölümü yok veya boş, testler başarısız, imza secret değerleri yok, uygulama arm64 değil.

## Elle sürüm (CI olmadan)

1. `VERSION=X.Y.Z scripts/bundle.sh` komutunu çalıştırın. Betik `build/Camsil-X.Y.Z.zip` ve `.sha256` dosyalarını oluşturur.
2. Sürüm notlarını alın ve sürümü yayınlayın:

   ```sh
   scripts/changelog-section.sh X.Y.Z > /tmp/notes.md
   gh release create vX.Y.Z --title "Camsil X.Y.Z" --notes-file /tmp/notes.md \
     build/Camsil-X.Y.Z.zip build/Camsil-X.Y.Z.zip.sha256
   ```

## İleride: Developer ID ve notarization

Apple Developer hesabı gelince şu adımları uygulayın:

1. Bir "Developer ID Application" sertifikası oluşturun. `.p12` dosyasını `SIGNING_CERT_P12_BASE64` ve `SIGNING_CERT_PASSWORD` secret değerlerine yazın.
2. `release.yml` içinde `CODESIGN_IDENTITY` değerini sertifika adı ile değiştirin.
3. `scripts/bundle.sh` içinde `--timestamp=none` yerine `--timestamp` kullanın.
4. Paketleme adımından sonra şu adımları ekleyin: `xcrun notarytool submit build/Camsil-X.Y.Z.zip --wait` ve `xcrun stapler staple build/Camsil.app`. Staple işleminden sonra zip ve `.sha256` dosyalarını yeniden oluşturun.
5. Sürüm notlarına şu satırı ekleyin: "Bu sürümden sonra macOS Ekran Kaydı iznini bir kez yeniden sorar." İmza değiştiği için soru bir kez çıkar.
