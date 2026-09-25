# Vorli — App Store materijali

Sve za App Store Connect na jednom mestu. Polja su poređana kako idu u ASC-u;
dužine su proverene u odnosu na Apple-ova ograničenja.

---

## 1. App Information

| Polje | Vrednost |
|---|---|
| **Name** (max 30) | `Vorli: Track, Budget & Plan` (27) — „Vorli“ ispod ikonice je početak imena, kako Apple traži |
| **Subtitle** (max 30) | `Skeniraj račun, vidi troškove` (29) — rezerva: `Fiskalni računi i troškovi` (26) |
| **Primary category** | Finance |
| **Secondary category** | Productivity (opciono) |
| **Content rights** | Ne sadrži sadržaj trećih strana |
| **Age rating** | Na sva pitanja „None/No“ → 4+ |
| **Privacy Policy URL** | https://bogstebole.github.io/vorli/privacy.html |
| **Support URL** | https://bogstebole.github.io/vorli/ |
| **Copyright** | `2026 <ime kao na developer nalogu>` |

**Jezik opisa:** ako u listi jezika u ASC-u postoji srpski, izaberi ga; ako ne
postoji, tekst ispod stavi u primarni jezik (npr. English (U.K.)) — jezik polja
ne mora da se poklapa sa jezikom teksta.

**Dostupnost:** Srbija. QR sa računa radi samo sa srpskim fiskalnim računima,
pa druge zemlje nemaju smisla za prvo izdanje.

---

## 2. App Privacy

- **Data Collection:** „No, we do not collect data from this app“ →
  prikazuje se **Data Not Collected**.
- Obrazloženje (za tebe, ne upisuje se nigde): nema naloga, analitike, oglasa ni
  servera; jedini mrežni zahtev je čitanje javne stranice računa na
  suf.purs.gov.rs, bez ličnih podataka. Isto piše u politici privatnosti i u
  `PrivacyInfo.xcprivacy`.

---

## 3. Verzija 1.0 — tekstovi

### Promotional Text (max 170) — 146

```
Skeniraj QR kod sa fiskalnog računa i za dve sekunde vidiš svaki artikal, koliko je šta poskupelo i gde ti ide plata. Sve ostaje na tvom telefonu.
```

### Keywords (max 100) — 93

Bez reči koje su već u imenu i podnaslovu (Apple ih računa same od sebe),
bez razmaka posle zareza:

```
fiskalni,QR,skener,budžet,štednja,potrošnja,cene,poskupljenje,kućni,finansije,plata,namirnice
```

### Description

```
Gde odoše pare? Vorli ti odgovara za dve sekunde.

Skeniraj QR kod sa fiskalnog računa — Vorli preuzme ceo račun sa sajta Poreske uprave, sa svim artiklima, cenama i PDV-om. Bez prepisivanja, bez slikanja gomile papira.

CEO MESEC NA JEDNOM EKRANU
Koliko si potrošio od zarade, koliko danas i kako se troškovi raspoređuju po danima. Prevuci za prethodne mesece.

VIDI ŠTA JE POSKUPELO
Vorli pamti cenu svakog artikla u svakoj prodavnici. Kad mleko ili kafa poskupe, vidiš za koliko procenata i od kada — sa grafikonom cele istorije.

GDE IDE PLATA
Dodeli kategoriju prodavnici jednom i svi njeni računi, prošli i budući, idu u tu kategoriju. Potrošnja po kategorijama uključuje i fiksne troškove.

PLANIRANJE
• Mesečna zarada i fiksni troškovi (kirija, struja, internet) koji se sami oduzimaju svakog meseca
• Ručni unos troška za pijacu i sve bez računa
• Lista želja: odvoji za slušalice ili letovanje i vidi da li stižeš do roka, po tome koliko ti prosečno ostaje

PRIVATNOST
Bez naloga, bez servera, bez reklama i praćenja. Računi, iznosi i kategorije ostaju isključivo na tvom telefonu.

PREMIUM
Tekući i prošli mesec su uvek besplatni. Premium otključava istoriju svih meseci, istoriju cena artikala, potrošnju po kategorijama i pretragu kroz sve račune.
Premium se plaća mesečno ili godišnje (pretplata koja se automatski obnavlja dok je ne otkažeš u podešavanjima App Store naloga) ili jednokratno, zauvek.

Uslovi korišćenja: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Politika privatnosti: https://bogstebole.github.io/vorli/privacy.html
```

---

## 4. Screenshots — 6,9″ (1320 × 2868)

Dve varijante, iste veličine; u ASC ide jedna. Redosled je redosled otpremanja.

- `screenshots/framed/` — sa naslovom iznad ekrana (preporuka)
- `screenshots/raw/` — čist ekran, ako želiš sam da ih uokviriš u Figmi

| # | Ekran | Naslov | Podnaslov |
|---|---|---|---|
| 1 | Početna | Gde odoše pare? | Ceo mesec na jednom ekranu. |
| 2 | Račun sa artiklima | Skeniraj QR sa računa. | Svaki artikal, za dve sekunde. |
| 3 | Istorija cene | Vidi šta je poskupelo. | Istorija cene svakog artikla. |
| 4 | Kategorije | Gde ide plata. | Potrošnja po kategorijama. |
| 5 | Računi po danima | Svi računi na okupu. | Po danima, sa zbirom dana. |
| 6 | Lista želja | Štedi za ono što želiš. | Vidiš kad stižeš do cilja. |

Podaci na slikama su izmišljeni (prodavnice i artikli bez pravih brendova —
Apple ne dozvoljava tuđe zaštićene znakove u metapodacima). Premium je
uključen, pa se vide i Premium funkcije; zato opis jasno kaže šta je Premium.

---

## 5. App Review Information

- **Sign-in required:** Ne
- **Contact:** tvoje ime, telefon, email
- **Attachment:** `review/qr-racun-za-recenzenta.png`
- **Notes** (recenzenti čitaju engleski):

```
Vorli is a personal expense tracker for Serbia. Every Serbian fiscal receipt carries a QR code that links to the Tax Administration's public verification page (suf.purs.gov.rs). The app opens that link, reads the receipt with all its items and stores it on the device.

HOW TO TEST SCANNING
Reviewers outside Serbia won't have a Serbian receipt, so one is attached (qr-racun-za-recenzenta.png, a real receipt of 13,825 RSD).
1. Open the attachment on another screen (Mac or second device).
2. In the app, tap the scan button at the bottom right and allow camera access.
3. Point the camera at the QR code. The receipt opens with all items; save it and it appears on Home and under "Detalji".

Without a camera: Planiranje (third tab) → "Dodaj trošak ručno" adds an expense by hand.

ACCOUNT AND DATA
No account or login. All data is stored locally on the device (SwiftData). No analytics, ads or third-party SDKs.

IN-APP PURCHASES
Premium: monthly and yearly auto-renewable subscriptions (one group) and a one-time lifetime purchase. The current and previous month are free; Premium unlocks older months, item price history, spending by category and search across all receipts. The paywall opens from Settings (gear icon on Home) → "Pogledaj Premium". Restore: Settings → "Povrati raniju kupovinu", or the button on the paywall.

The interface is in Serbian (Latin script).
```

---

## 6. Premium proizvodi (In-App Purchases)

ID-jevi moraju da budu tačno ovi — tako ih traži kod (`PremiumStore.swift`).

| Product ID | Tip | Display name (max 35) | Description (max 55) |
|---|---|---|---|
| `bogste.ReceiptTracker.premium.monthly` | Auto-renewable, 1 mesec | Premium – mesečno | Istorija svih meseci i cena artikala |
| `bogste.ReceiptTracker.premium.yearly` | Auto-renewable, 1 godina | Premium – godišnje | Istorija svih meseci i cena artikala |
| `bogste.ReceiptTracker.premium.lifetime` | Non-consumable | Premium – zauvek | Istorija svih meseci i cena artikala |

- Obe pretplate u **istoj grupi** (npr. „Vorli Premium“).
- U test konfiguraciji (`Premium.storekit`) godišnja pretplata ima **1 nedelju
  besplatno** — ako to želiš i uživo, dodaj Introductory Offer „Free, 1 week“
  na godišnju.
- Test cene u `Premium.storekit`: 1,99 mesečno · 9,99 godišnje · 24,99 zauvek
  (USD). Prave cene biraš ti u ASC-u.
- Svaki proizvod traži **Review screenshot**: screenshot paywall-a (Podešavanja →
  Pogledaj Premium).
- Proizvodi se šalju na review **zajedno sa verzijom 1.0** (u verziji, sekcija
  „In-App Purchases and Subscriptions“ → dodaj sva tri).

---

## 7. Redosled

1. ☐ App Information, App Privacy, Pricing & Availability (Srbija)
2. ☐ Tri Premium proizvoda + review screenshot paywall-a
3. ☐ Verzija 1.0: tekstovi, screenshots, App Review Information + QR prilog
4. ☐ Build: povećaj build broj (trenutno 4 → 5), Product → Archive → Distribute
   → App Store Connect
5. ☐ Izaberi build u verziji 1.0, dodaj IAP-ove, Submit for Review
