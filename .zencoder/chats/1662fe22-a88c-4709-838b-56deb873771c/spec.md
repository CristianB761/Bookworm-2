# Technical Specification: Gutendex API Integration

## Technical Context
- **Language/Version**: Dart/Flutter
- **Primary Dependencies**: `http`, `firebase_core`, `cloud_firestore`, `firebase_auth`, `url_launcher`
- **API**: [Gutendex](https://gutendex.com/) (Project Gutenberg eBook catalog)

## Technical Implementation Brief
- Implement `GutendexService` to handle API calls to `gutendex.com`.
- Update `lib/API/modelos.dart` to ensure `Libro` can be instantiated from Gutendex JSON.
- Modify `lib/buscar.dart` to perform concurrent searches on both OpenLibrary and Gutendex, merging results.
- Create a new "Public Domain" browse section.
- Leverage existing `DetallesLibro` for book details, adding a "Read Online" button that opens the external browser.

## Source Code Structure
- `lib/API/gutendex_service.dart`: New service for Gutendex API.
- `lib/API/modelos.dart`: Updated `Libro` factory.
- `lib/buscar.dart`: Updated search logic.
- `lib/public_domain.dart`: New page for browsing public domain books.

## Contracts
- **Libro Model**: Add `urlLectura` field (String?) to store the link to the eBook.
- **Gutendex API mapping**:
    - `id`: `id.toString()`
    - `titulo`: `title`
    - `autores`: `authors.map((a) => a.name).toList()`
    - `urlMiniatura`: `formats["image/jpeg"]`
    - `urlLectura`: `formats["text/html"]` (prioritized) or `formats["application/epub+zip"]`

## Delivery Phases
1. **API Service & Model**: Create `GutendexService` and update `Libro` model.
2. **Integrated Search**: Update the search page to show mixed results.
3. **Public Domain Page**: Implement the dedicated browsing page.
4. **Offline & External Links**: Ensure saving works and "Read Online" functionality is added.

## Verification Strategy
- **Unit Tests**: Test `GutendexService` with mocked API responses.
- **Integration Tests**: Verify search merging logic in `buscar.dart`.
- **Manual Verification**: Use the app to search for "Dickens" and verify results from both sources appear and links open correctly.
