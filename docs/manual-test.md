# Camsil elle test listesi

Her sürümden önce bu listeyi uygulayın. Apple Silicon bir Mac kullanın.

## Hazırlık

```sh
scripts/bundle.sh && open build/Camsil.app
```

Esc tuşu her zaman çıkış yapar. Bir adım takılırsa Esc tuşuna basın.

## 1. İzin

1. İzni sıfırlayın: `tccutil reset ScreenCapture com.ahmetkorkmaz.Camsil`. Camsil uygulamasını açın.
   - Beklenen: macOS Ekran Kaydı iznini sorar. Camsil kapanır.
2. İzni verin. Camsil uygulamasını yeniden açın.
   - Beklenen: ekran tozlu bir cam gibi görünür. Kir 1,5 saniyede belirir.
3. Camsil uygulamasını kapatın ve `scripts/bundle.sh` ile yeniden derleyin. Uygulamayı açın.
   - Beklenen: "Camsil Self-Signed" sertifikası varsa macOS izni yeniden sormaz.

## 2. Araçlar

1. Sol tıklayın. Beklenen: şişe su püskürtür. Damlalar camdan aşağı akar ve yaklaşık 8 saniyede kurur.
2. Sol tuşu basılı tutun. Beklenen: şişe saniyede yaklaşık 4 kez püskürtür.
3. Sağ tıklayın, sonra Space tuşuna basın. Beklenen: her basışta araç şişe ile bez arasında değişir.
4. 1 ve 2 tuşlarına basın. Beklenen: 1 şişeyi, 2 bezi seçer.
5. Islak camı bezle silin. Beklenen: cam temizlenir. Gıcırtı sesinin perdesi hız ile değişir (ses dosyaları varsa).
6. Kuru camı bezle silin. Beklenen: toz yalnızca dağılır, cam temizlenmez.

## 3. Bitiş ve çıkış

1. Camı temizleyin. Beklenen: HUD `%N temiz` değerini gösterir. %95 değerinde cam parlar ve pencere kapanır.
2. Camsil uygulamasını açın ve Esc tuşuna basın. Beklenen: Camsil hemen kapanır.
3. Camsil uygulamasını açın ve Cmd+Q tuşlarına basın. Beklenen: Camsil hemen kapanır.
4. Camsil uygulamasını açın ve 2 dakika bekleyin. Beklenen: Camsil kendisi kapanır.

## 4. Odak ve ekran

1. Camsil açıkken Cmd+Tab ile başka bir uygulamaya geçin. Sonra cama tıklayın.
   - Beklenen: Camsil geri gelir ve tıklama çalışır.
2. Camsil açıkken ana ekranın çözünürlüğünü değiştirin.
   - Beklenen: Camsil kapanır ve çökmez.

## 5. Dağıtım

1. Kurulum komutunu çalıştırın:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/ahmetkorkmaz3/Camsil/main/install.sh | sh
   ```

   - Beklenen: komut son sürümü indirir, SHA-256 değerini kontrol eder ve `/Applications/Camsil.app` kurar.
2. Uygulamanın sürümünü kontrol edin:

   ```sh
   defaults read /Applications/Camsil.app/Contents/Info.plist CFBundleShortVersionString
   ```

   - Beklenen: değer etiketteki sürüm ile aynı.
3. İmzayı kontrol edin: `codesign -dvv /Applications/Camsil.app 2>&1 | grep Authority`
   - Beklenen: `Authority=Camsil Self-Signed`.
4. Camsil uygulamasını açın. Beklenen: Gatekeeper uyarısı çıkmaz.
5. Kurulum komutunu yeniden çalıştırın. Beklenen: güncelleme sonrası macOS Ekran Kaydı iznini yeniden sormaz.
