# The stored photo is the entry JPEG, and one read displays it

A new InspectionItem photo is fitted and encoded once, when it enters the form. Save writes that JPEG. The detail screen, the report, and the form preview turn those bytes into an image through one display read at a pixel size. A leftover file is copied into the blob as those file bytes. A read does not make a new JPEG from the cache.

**Considered options:** fit and encode again at save; leave the detail screen, the report, and the form on three decodes; re-encode a leftover file at quality 0.8 on the way into the blob.

**Consequences:** Do not fit or encode on save. Do not add another decode beside the display read. Do not re-encode a leftover file. `getPhotoThumbnail` stays. SiteDocument entry stays. The five-photo cap stays. Photos already stored stay until that item's photos change (ADR 0025). Callers still ask for photo bytes (ADR 0005).
