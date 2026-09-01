# Photo bytes at the InspectionItem seam, not slots or files

InspectionItem persist is `replacePhotos([Data])` and `photoBytes()`. Slot keys and documents paths stay in the implementation. New writes are Core Data bytes only; leftover files are a private read fallback. We considered keeping `setPackedPhotos` as the write path, or writing a documents file plus a blob on every save. Dual packing just moves; CloudKit already wants blobs. Screens may still ask for unindexed images (`photoCount`, `hasPhoto`, `getAllPhotosSync`, `getPhotoThumbnail`). The five-photo cap stays on InspectionItem.

**Considered options:** packed `(data, urlPath)` writes on Intake; blob plus documents file on every save; InspectionItem returns only bytes and every screen decodes JPEG; `photoURL` predicate on CoreDataManager; bytes in, bytes out, files as read fallback (chosen).

**Consequences:** Do not expose `photoData(at:)` / `photoURLString(at:)` / `setPackedPhotos`. Do not write documents files from Intake. CoreDataManager must not name `photoURL`…`photoURL5`; fetch items with local files through InspectionItem. Tests assert `photoBytes` / `replacePhotos`, not slot keys. Report already reads `photoBytes()` (see ADR-0003).
