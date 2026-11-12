# A stored photo is not the camera original

An InspectionItem holds at most five photos, and a SiteDocument holds a photo or PDF of at most 10 MB, at most five. New photos are reduced to a 1600-pixel long edge, then stored as JPEG at quality 0.8, when the photo enters the form. Photos already stored stay until the next time that item's or that document's photos change. A PDF stays a PDF. The five-photo cap and the 10 MB cap stay. 1600 pixels covers the on-screen photo and a Report slot. The camera original is gone for any photo saved after this, including fine detail in a crack, a nameplate, or a photographed drawing. This follows ADR 0005: callers still ask for photo bytes.

**Considered options:** keep the camera JPEG; rewrite every stored photo in one pass; shrink only at save and leave the full image in the form; 1600-pixel JPEG for new photos only (chosen).

**Consequences:** Do not migrate photos that are already stored. Do not downsample a PDF. Do not change the five-photo cap or the 10 MB SiteDocument cap. A photo saved after this decision cannot be restored to the camera original. Report reads the stored bytes (ADR 0003).
