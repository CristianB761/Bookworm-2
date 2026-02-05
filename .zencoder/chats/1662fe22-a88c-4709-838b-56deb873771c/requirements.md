# Feature Specification: Gutendex API Integration

## User Stories

### User Story 1 - Search Public Domain Books
**Acceptance Scenarios**:
1. **Given** the user is on the search page, **When** they enter a search term, **Then** they should see results from both OpenLibrary and Gutendex mixed together.
2. **Given** the user is in the "Public Domain" section, **When** they browse or search, **Then** they should only see books from the Gutendex API.

### User Story 2 - Accessing Gutendex Books
**Acceptance Scenarios**:
1. **Given** a user has found a Gutendex book, **When** they select it, **Then** they should be taken to the book's details page.
2. **Given** a user is on the details page of a Gutendex book, **When** they click "Read", **Then** the book should open in an external browser.

### User Story 3 - Offline Synchronization
**Acceptance Scenarios**:
1. **Given** a user has "saved" or "favorited" a Gutendex book, **When** they trigger a synchronization, **Then** the book's metadata should be available offline.

---

## Requirements

- **API Integration**: Implement a `GutendexService` to fetch data from `https://gutendex.com/`.
- **Mixed Search**: Update `lib/buscar.dart` to fetch results from both `OpenLibrary` and `GutendexService` and merge them.
- **Dedicated Section**: Create a new UI section or page dedicated to browsing Gutendex books.
- **Model Mapping**: Ensure Gutendex book data is correctly mapped to the existing `Libro` model.
- **External Links**: Implement logic to extract the most appropriate download/read URL (e.g., HTML or EPUB) from Gutendex's `formats` field.
- **Offline Support**: Ensure Gutendex books can be saved to Firestore and synchronized for offline access using the existing system.

## Success Criteria

- Users can search and find books from Project Gutenberg (via Gutendex).
- Search results are mixed seamlessly with OpenLibrary results.
- Users can navigate to an external browser to read the books.
- Gutendex books can be saved and are handled by the offline synchronization system.
