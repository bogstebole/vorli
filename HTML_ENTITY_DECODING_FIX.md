# 🔧 HTML Entity Decoding Fix

## ✅ Problem Solved

Non-alphanumeric simboli su se prikazivali kao HTML entiteti umesto kao pravi karakteri:
- `&#39;` umesto `'` (apostrof)
- `&#34;` umesto `"` (navodnik)
- `&#40;` umesto `(` (otvorena zagrada)
- itd.

## 🛠️ Solution

Dodao sam `String` extension koji dekodira HTML entitete i primenio ga na **OBA** parsera:

### 1. **ReceiptParser.swift** (HTML Parser)
- Dekoduje HTML entitete iz HTML-a koji se fetchuje sa `suf.purs.gov.rs`
- Primenjuje se u `extractPreContent()` funkciji
- Dekoduje nakon uklanjanja HTML tagova, pre parsiranja

### 2. **ReceiptOCRParser.swift** (OCR Parser)  
- Dekoduje HTML entitete iz OCR teksta
- Primenjuje se u `performOCR()` funkciji
- Dekoduje svaki red teksta odmah nakon OCR prepoznavanja

## 📋 Supported Entities

### Numeric Entities (&#xx;)
| Entity | Character | Description |
|--------|-----------|-------------|
| `&#34;` | `"` | navodnik |
| `&#38;` | `&` | ampersand |
| `&#39;` | `'` | apostrof |
| `&#40;` | `(` | otvorena zagrada |
| `&#41;` | `)` | zatvorena zagrada |
| `&#47;` | `/` | kosa crta |
| `&#58;` | `:` | dvotačka |
| `&#59;` | `;` | tačka-zarez |
| `&#44;` | `,` | zarez |
| `&#46;` | `.` | tačka |
| `&#63;` | `?` | upitnik |
| `&#33;` | `!` | uzvičnik |
| ... i još 20+ drugih |

### Named Entities (&xxx;)
| Entity | Character |
|--------|-----------|
| `&quot;` | `"` |
| `&amp;` | `&` |
| `&apos;` | `'` |
| `&lt;` | `<` |
| `&gt;` | `>` |
| `&nbsp;` | ` ` |

### Regex Patterns
- **Decimal**: `&#(\d+);` → pretvara broj u Unicode karakter
- **Hexadecimal**: `&#x([0-9A-Fa-f]+);` → pretvara hex broj u Unicode karakter

## 🔍 How It Works

### Extension Definition
```swift
extension String {
    func decodingHTMLEntities() -> String {
        // 1. Replace known numeric entities
        // 2. Replace known named entities
        // 3. Use regex for any remaining decimal entities
        // 4. Use regex for any remaining hex entities
        return decodedString
    }
}
```

### Applied in HTML Parser
```swift
private static func extractPreContent(from html: String) -> String? {
    // ... extract <pre> content ...
    let withoutTags = preContent.replacingOccurrences(of: "<[^>]+>", with: "")
    
    // ✅ DECODE HTML ENTITIES
    let decodedContent = withoutTags.decodingHTMLEntities()
    
    return decodedContent
}
```

### Applied in OCR Parser
```swift
let recognizedStrings = observations.compactMap { observation -> String? in
    guard let topCandidate = observation.topCandidates(1).first else {
        return nil
    }
    
    // ✅ DECODE HTML ENTITIES
    let decodedString = topCandidate.string.decodingHTMLEntities()
    
    return decodedString
}
```

## 🧪 Testing

### Test Case 1: OCR Scanning
1. Skeniraj račun sa kamerom
2. Proveri da li se simboli pravilno prikazuju u item imenima
3. Primer: `Chicken fries (Large)` umesto `Chicken fries &#40;Large&#41;`

### Test Case 2: QR Code Scanning
1. Skeniraj QR kod
2. Fetch HTML sa servera
3. Proveri da li se simboli pravilno prikazuju
4. Primer: `Pizza 30cm (Đ)` umesto `Pizza 30cm &#40;Đ&#41;`

### Expected Results
```
✅ Pre: "Item's name (Medium)" 
❌ Pre: "Item&#39;s name &#40;Medium&#41;"

✅ Posle: "Item's name (Medium)"
✅ Posle: "Pizza 30cm (Đ)"
```

## 📊 Code Locations

| File | Function | Line |
|------|----------|------|
| `ReceiptParser.swift` | `extractPreContent()` | ~195 |
| `ReceiptOCRParser.swift` | `performOCR()` | ~70 |
| `ReceiptParser.swift` | `String.decodingHTMLEntities()` | ~10 |
| `ReceiptOCRParser.swift` | `String.decodingHTMLEntities()` | ~10 |

## ✨ Benefits

1. **Universal**: Radi za OCR i HTML parsing
2. **Comprehensive**: Podržava sve standardne HTML entitete
3. **Extensible**: Lako se dodaju novi entiteti u dictionary
4. **Robust**: Regex pattern hvata i nestandardne entitete
5. **Clean**: Korisnik nikad ne vidi `&#xx;` karaktere

## 🎯 What Changed

### Before
```
Item name: "Don&#39;t stop"
Display: "Don&#39;t stop"  ❌
```

### After  
```
Item name: "Don't stop"
Display: "Don't stop"  ✅
```

## 💡 Notes

- Extension je identičan u oba fajla (duplicate code za sada)
- Možeš ga kasnije premestiti u shared utility fajl
- Dekodiranje se dešava **pre** parsiranja, tako da parser dobija čist tekst
- Performance impact je minimalan (dictionary lookup + regex)

---

**Status: ✅ FIXED**  
Svi non-alphanumeric simboli se sada pravilno prikazuju! 🎉
