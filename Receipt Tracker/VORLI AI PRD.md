# Vorli — AI Financial Assistant
### Feature PRD · Verzija 1.1 · Mart 2026 · iOS

---

## Pregled

Vorli dobija AI asistenta ugrađenog direktno u aplikaciju. Korisnik razgovara prirodnim jezikom — traži izveštaje, dobija plan potrošnje za naredni mesec, analizira navike i preuzima PDF report. Sve radi nad lokalnim SwiftData podacima, bez uploadovanja fajlova na eksterne servise.

| | |
|---|---|
| **Platforma** | iOS — SwiftUI + SwiftData |
| **AI Provider** | Anthropic Claude API (`claude-sonnet-4-20250514`) |
| **Jezik UI** | Srpski (internacionalizacija planirana) |
| **Prioritet** | High — core differentiator |
| **Procenjeno** | 2–3 sprint iteracije |
| **Cena / mesec** | < $1 USD pri normalnoj upotrebi |

---

## Problem

Korisnici akumuliraju podatke o potrošnji ali nemaju sistem koji im pomaže da razumeju šta se dešava i šta da urade sledeće. Klasični reporti prikazuju samo istoriju — bez plana, bez konteksta, bez akcije.

---

## UX Flow

Vorli ne gura sadržaj korisniku — on ga otvara kad hoće. Jedini izuzetak je kraj meseca.

| Ekran / Akcija | Opis |
|---|---|
| **Lista računa** | Default ekran — korisnik skenira i gleda račune normalno |
| **AI CTA dugme** | Floating button ili tab koji otvara chat sa asistentom |
| **AI Chat** | Slobodan razgovor — izveštaj, plan, pretraga, OCR foto unos |
| **Kraj meseca popup** | Smart notifikacija: "Mesec završen — tvoj izveštaj je spreman" |
| **PDF export** | Iz chata jednim klikom — preuzimanje ili share sheet |

---

## Funkcionalnosti

| | Funkcionalnost | Opis |
|---|---|---|
| 💬 | **AI Chat** | Ugrađen chat interfejs. Korisnik piše slobodnim jezikom, asistent ima pristup svim računima kao kontekst. |
| 📊 | **Mesečni izveštaj** | "Generiši izveštaj za ovaj mesec" — ukupno, top prodavnice, kategorije, prosek po danu, poređenje sa prethodnim mesecom. |
| 📅 | **Nedeljni izveštaj** | Operativni pregled za tekuću ili prethodnu nedelju — fokus na anomalijama i trendovima. |
| 📋 | **Mesečni plan** | AI generiše plan za naredni mesec: budžet po kategorijama, lista za bulk kupovinu, procena goriva. |
| 🛒 | **Plan nabavke** | Razdvaja bulk kupovinu (jednom mesečno) od svežeg (nedeljno). Količine na osnovu istorije. |
| 🧠 | **AI Insights** | AI interpretira podatke: "Trošiš 3x više vikendom" ili "Gorivo ti je poraslo 40% — procena za april je X RSD". |
| 🎯 | **Budžet praćenje** | 50/20/30 framework. AI upozorava kada korisnik prekorači planiranu kategoriju. |
| 📄 | **PDF export** | Clean, minimalistički PDF — izveštaj ili plan — direktno iz chata na iOS uređaj. |
| 📷 | **Foto OCR via AI** | Ako QR kod ne radi, korisnik fotografiše račun. Claude parsira stavke vizuelno i dodaje ih u listu računa. |
| 🔍 | **Slobodna pretraga** | "Koliko sam puta kupio jaja ove godine?" ili "Gde su mi cigarete najjeftinije?" |
| 🔔 | **Kraj meseca notif.** | Smart popup na poslednji dan u mesecu — korisnik jednim klikom otvara report ili pokreće plan. |

---

## Mesečni Plan — Detalji

### Plan nabavke — dve kategorije

| Tip | Šta uključuje | Logika |
|---|---|---|
| **Bulk — jednom mesečno** | Ulje, brašno, meso za zamrzivač, deterdžent, toalet papir, konzerve | Namirnice koje ne propadaju brzo — AI prepoznaje iz naziva artikala |
| **Sveže — nedeljno** | Hleb, mleko, jaja, voće, povrće, jogurt | Kupuje se po potrebi, AI procenjuje nedeljne količine iz navika |

### Primer AI outputa za plan

```
PLAN ZA APRIL 2026

Bulk kupovina (jednom):
  • Ulje — 2L x 2 (~460 RSD)
  • Meso za zamrzivač — ~2kg (~1.800 RSD)
  • Deterdžent, sredstva za čišćenje — ~600 RSD

Sveže (nedeljno x4):
  • Hleb — ~2 komada/nedeljno = 8 ukupno
  • Jaja — 1 kutija/nedeljno = 4 ukupno
  • Mleko, jogurt — po potrebi

Gorivo: procena ~3.200 RSD (prosek poslednjih 3 meseca)

Ukupan procenjeni budžet za namirnice + gorivo: ~14.500 RSD
Preostaje za ostalo u kategoriji 'potrebe': ~XXX RSD
```

---

## Budžet Framework — 50/20/30

| Kategorija | Procenat | Opis |
|---|---|---|
| **Potrebe** | 50% | Fiksni troškovi, hrana, gorivo, komunalije |
| **Štednja / Kuća** | 30% | Agresivna štednja dok traje gradnja — prioritet |
| **Želje** | 20% | Kafići, izlasci, impulzivne kupovine, razonoda |

---

## AI Prompt Sistem

Troslojna arhitektura koja daje AI-u precizan kontekst za svaki tip zahteva.

### Sloj 1 — Sistem prompt (statički)

```
Ti si Vorli, finansijski asistent unutar iOS aplikacije za praćenje troškova.
Korisnik govori srpski — uvek odgovaraj na srpskom.

TON: direktan, konkretan, bez finansijskog žargona. Kao prijatelj koji razume pare.
FORMAT: kratak uvod (1 rečenica) → ključni nalazi → jedan konkretan savet.
NIKAD ne pravi liste od više od 5 stavki. Manje je više.

Za izveštaje: uvek poredi sa prethodnim periodom ako postoje podaci.
Za planove: razdvoji bulk kupovinu (jednom mesečno) od svežeg (nedeljno).
Za insights: budi specifičan — napiši iznos, procenat, datum, prodavnicu.
Na kraju svakog izveštaja ili plana: jedan konkretan savet za naredni period.
```

### Sloj 2 — Korisnički profil (dinamički, čuva se lokalno)

```json
{
  "mesecni_prihod": "[vrednost iz app-a za tekući mesec]",
  "budzet_model": "50/20/30",
  "aktivni_cilj": "[npr. štednja za kuću — target X EUR/mesečno]",
  "wishlist": "[npr. kola — bez roka]",
  "valuta": "RSD",
  "lokacija": "Srbija"
}
```

> Korisnički profil se čuva u `UserDefaults` i šalje se u svakom API requestu.
> Mesečni prihod se povlači dinamički iz unosa korisnika za tekući mesec.

### Sloj 3 — Kontekst po tipu zahteva

```json
{
  "tip_zahteva": "REPORT | PLAN | PRETRAGA | OCR",
  "racuni_period": "[JSON array računa za traženi period]",
  "racuni_prethodni": "[JSON array — samo za REPORT, za poređenje]"
}
```

**Struktura jednog računa:**
```json
{
  "prodavnica": "Domaća Trgovina DOO Beograd",
  "datum": "2026-03-10",
  "vreme": "08:54",
  "ukupno_rsd": 1037,
  "stavke": [
    { "naziv": "Cigarete Sobranie Gold", "cena": 530, "kolicina": 1 },
    { "naziv": "Jaja iz podnog uzgoja", "cena": 234, "kolicina": 1 }
  ]
}
```

### Tipovi zahteva

| Tip | Šta AI radi |
|---|---|
| `REPORT` | Analizira prošli period, poredi sa prethodnim, daje insights i jedan savet |
| `PLAN` | Generiše budžet i plan nabavke za naredni period na osnovu istorije i ciljeva |
| `PRETRAGA` | Odgovara na slobodno pitanje iz istorije transakcija |
| `OCR` | Parsira fotografiju računa i vraća strukturisane stavke za unos u SwiftData |

---

## Tehnička Arhitektura

| | |
|---|---|
| **Data source** | SwiftData — fetch računa i stavki lokalno, serijalizacija u JSON |
| **API poziv** | `POST /v1/messages` — sistem prompt + korisnički profil + kontekst |
| **Streaming** | SSE streaming za real-time prikaz odgovora u chatu |
| **Image input** | Base64 fotografija direktno u `message.content` array (za OCR) |
| **Korisnički profil** | `UserDefaults` — šalje se u svakom requestu kao deo sistem prompta |
| **PDF generisanje** | PDFKit (iOS native) na osnovu Markdown outputa od AI-a |
| **Notifikacije** | `UNUserNotificationCenter` — local notification na poslednji dan u mesecu |

---

## Van opsega — v1.0

- Sinhronizacija sa bankovnim računom ili eksternim servisima
- Zajednički budžet / multi-user
- Push notifikacije za prekoračenje budžeta tokom meseca
- Predikcija troškova ML modelom
- Automatska kategorizacija bez AI-a

---

*Vorli · Interni dokument · Verzija 1.1 · Mart 2026*
